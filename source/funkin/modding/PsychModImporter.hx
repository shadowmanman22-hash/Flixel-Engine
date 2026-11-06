package funkin.modding;

#if sys
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/**
 * Imports standard four-key Psych charts and OGG audio into native Polymod packs.
 * Sources are never modified. Generated packs are imported once, before Polymod scans.
 * This is a chart compatibility layer, not a Lua runtime.
 */
class PsychModImporter
{
  public static function importAll(sourceRoot:String, modRoot:String):Void
  {
    if (!FileSystem.exists(sourceRoot) || !FileSystem.isDirectory(sourceRoot)) return;
    for (name in FileSystem.readDirectory(sourceRoot))
    {
      var source = '$sourceRoot/$name';
      if (StringTools.startsWith(name, '.') || !FileSystem.isDirectory(source)) continue;
      try
      {
        var target = '$modRoot/psych-${safeId(name)}';
        // Never overwrite an installed mod, including a user's edited conversion.
        if (FileSystem.exists(target)) continue;
        importPack(source, target);
      }
      catch (e:Dynamic)
      {
        trace('Psych import failed for $name: $e');
      }
    }
  }

  public static function importPack(source:String, target:String):Int
  {
    if (FileSystem.exists(target)) throw 'Destination already exists: $target';
    var staging = target + '.importing';
    if (FileSystem.exists(staging)) removeTree(staging);
    try
    {
      var count = buildPack(source, staging);
      if (count > 0) FileSystem.rename(staging, target);
      else if (FileSystem.exists(staging)) removeTree(staging);
      return count;
    }
    catch (e:Dynamic)
    {
      if (FileSystem.exists(staging)) removeTree(staging);
      throw e;
    }
  }

  static function removeTree(path:String):Void
  {
    if (FileSystem.isDirectory(path))
    {
      for (name in FileSystem.readDirectory(path)) removeTree('$path/$name');
      FileSystem.deleteDirectory(path);
    }
    else
      FileSystem.deleteFile(path);
  }

  static function buildPack(source:String, target:String):Int
  {
    var dataRoot = '$source/data';
    if (!FileSystem.exists(dataRoot)) throw 'Missing Psych data/ folder';
    var reports:Array<String> = [
      'Chart/audio import only. Lua/HScript, custom characters, stages, events and note types require a native port.',
      'Imported songs use Boyfriend, Dad and the default stage. Remove this generated pack to reimport updated source files.'
    ];
    var songs:Array<String> = [];
    for (folder in FileSystem.readDirectory(dataRoot))
    {
      var directory = '$dataRoot/$folder';
      if (!FileSystem.isDirectory(directory)) continue;
      var id = '${safeId(haxe.io.Path.withoutDirectory(target).split('.importing')[0])}-${safeId(folder)}';
      if (songs.indexOf(id) != -1) throw 'Song ID collision: $folder';
      var notes:Dynamic = {};
      var speeds:Dynamic = {};
      var difficulties:Array<String> = [];
      var reference:Dynamic = null;
      var referenceTimeline:String = null;
      var referenceCamera:String = null;
      var files = FileSystem.readDirectory(directory);
      // Prefer normal as the canonical metadata/camera timeline when available.
      files.sort((a, b) -> a == '$folder.json' ? -1 : (b == '$folder.json' ? 1 : Reflect.compare(a, b)));
      for (filename in files)
      {
        if (!StringTools.endsWith(filename, '.json')) continue;
        var stem = filename.substr(0, filename.length - 5);
        if (stem != folder && !StringTools.startsWith(stem, '$folder-')) continue;
        var difficulty = stem == folder ? 'normal' : stem.substr(folder.length + 1);
        if (!~/^[a-z0-9_-]+$/.match(difficulty)) continue;
        try
        {
          var song:Dynamic = Json.parse(File.getContent('$directory/$filename')).song;
          var result = convertChart(song);
          var timeline = Json.stringify(result.timeChanges);
          var camera = Json.stringify(result.events);
          if (
            referenceTimeline != null
            && (referenceTimeline != timeline || referenceCamera != camera)
          ) throw 'Different BPM/camera timeline between difficulties';
          if (Reflect.hasField(notes, difficulty)) throw 'Duplicate difficulty: $difficulty';
          Reflect.setField(notes, difficulty, result.notes);
          Reflect.setField(speeds, difficulty, number(song.speed, 1));
          difficulties.push(difficulty);
          if (reference == null)
          {
            reference = song;
            referenceTimeline = timeline;
            referenceCamera = camera;
          }
          if (result.hasEvents) reports.push('$folder/$filename: Psych events are not imported.');
        }
        catch (e:Dynamic)
        {
          reports.push('$folder/$filename skipped: $e');
        }
      }
      if (difficulties.length == 0) continue;
      var audioRoot = '$source/songs/$folder';
      if (!FileSystem.exists('$audioRoot/Inst.ogg'))
      {
        reports.push('$folder skipped: missing songs/$folder/Inst.ogg');
        continue;
      }
      var base = '$target/data/songs/$id/$id';
      writeJson('$base-metadata.json', {
        version: '2.2.4',
        songName: reference.song == null ? folder : Std.string(reference.song),
        artist: 'Psych mod',
        generatedBy: 'Flixel Engine Psych chart importer',
        timeFormat: 'ms',
        timeChanges: Json.parse(referenceTimeline),
        playData: {
          songVariations: [],
          difficulties: difficulties,
          characters: {
            player: 'bf',
            girlfriend: 'gf',
            opponent: 'dad',
            instrumental: ''
          },
          stage: 'mainStage',
          noteStyle: 'funkin'
        }
      });
      // Camera focus follows the same section ownership used to map the notes.
      writeJson('$base-chart.json', {
        version: '2.0.0',
        scrollSpeed: speeds,
        notes: notes,
        events: convertChart(reference).events,
        generatedBy: 'Flixel Engine Psych chart importer'
      });
      var outputAudio = '$target/songs/$id';
      FileSystem.createDirectory(outputAudio);
      File.copy('$audioRoot/Inst.ogg', '$outputAudio/Inst.ogg');
      for (audio in ['Voices.ogg', 'Voices-Player.ogg', 'Voices-Opponent.ogg'])
      {
        if (!FileSystem.exists('$audioRoot/$audio')) continue;
        var outputName = switch (audio)
        {
          case 'Voices-Player.ogg':
            'Voices-bf.ogg';
          case 'Voices-Opponent.ogg':
            'Voices-dad.ogg';
          default:
            audio;
        };
        File.copy('$audioRoot/$audio', '$outputAudio/$outputName');
      }
      songs.push(id);
    }
    if (songs.length == 0)
    {
      // Keep diagnostics outside the mod list, without marking a failed import installed.
      FileSystem.createDirectory(haxe.io.Path.directory(target));
      File.saveContent('$target-import-report.txt', reports.join('\n'));
      return 0;
    }
    writeJson('$target/data/levels/${safeId(haxe.io.Path.withoutDirectory(target).split('.importing')[0])}.json', {
      version: '1.0.2',
      name: haxe.io.Path.withoutDirectory(source),
      titleAsset: 'storymenu/titles/week1',
      props: [],
      songs: songs,
      visible: false
    });
    File.saveContent('$target/psych-import-report.txt', reports.join('\n'));
    // Publish metadata last, so Polymod never sees an incomplete pack as installed.
    writeJson('$target/_polymod_meta.json', {
      title: 'Psych: ${haxe.io.Path.withoutDirectory(source)}',
      description: 'Imported Psych charts and audio; see psych-import-report.txt.',
      contributors: [],
      api_version: '0.8.0',
      mod_version: '1.0.0'
    });
    return songs.length;
  }

  public static function convertChart(song:Dynamic):Dynamic
  {
    if (song == null || !Std.isOfType(song.notes, Array)) throw 'Expected a Psych song with note sections';
    var bpm = number(song.bpm, 100);
    var changes:Array<Dynamic> = [{
      t: 0,
      bpm: bpm,
      n: 4,
      d: 4
    }];
    var notes:Array<Dynamic> = [];
    var events:Array<Dynamic> = [];
    var time:Float = 0;
    var lastOwner:Null<Bool> = null;
    var sections:Array<Dynamic> = song.notes;
    for (section in sections)
    {
      if (section.changeBPM == true)
      {
        bpm = number(section.bpm, bpm);
        if (time == 0) changes[0].bpm = bpm;
        else
          changes.push({
            t: time,
            bpm: bpm,
            n: 4,
            d: 4
          });
      }
      var owner:Bool = section.mustHitSection == true;
      if (owner != lastOwner) events.push({
        t: time,
        e: 'FocusCamera',
        v: {
          char: owner ? 0 : 1
        }
      });
      lastOwner = owner;
      if (section.gfSection == true || section.altAnim == true) throw 'GF/alternate-animation sections require a native port';
      if (!Std.isOfType(section.sectionNotes, Array)) throw 'Missing sectionNotes';
      var sectionNotes:Array<Dynamic> = section.sectionNotes;
      for (note in sectionNotes)
      {
        if (!Std.isOfType(note, Array) || note.length < 3) throw 'Invalid note';
        var lane:Float = note[1];
        if (!Math.isFinite(lane) || lane < 0 || lane > 7 || lane != Math.floor(lane)) throw 'Only four-key note lanes 0..7 are supported';
        if (note.length > 3 && note[3] != null && note[3] != '' && note[3] != 0) throw 'Custom note types require a native port';
        var timestamp:Float = note[0];
        var length:Float = note[2];
        if (!Math.isFinite(timestamp) || timestamp < 0 || !Math.isFinite(length) || length < 0) throw 'Invalid note timing';
        var player = lane < 4 ? owner : !owner;
        notes.push({
          t: timestamp,
          d: Std.int(lane) % 4 + (player ? 0 : 4),
          l: length
        });
      }
      var beats = section.sectionBeats != null ? number(section.sectionBeats, 4) : number(section.lengthInSteps, 16) / 4;
      time += beats * 60000 / bpm;
    }
    notes.sort((a, b) -> Reflect.compare(a.t, b.t));
    return {
      notes: notes,
      events: events,
      timeChanges: changes,
      hasEvents: Std.isOfType(song.events, Array) && song.events.length > 0};
  }

  static function number(value:Dynamic, fallback:Float):Float
  {
    if (value == null) return fallback;
    var result = Std.parseFloat(Std.string(value));
    if (!Math.isFinite(result) || result <= 0) throw 'Expected a positive number';
    return result;
  }

  static function safeId(value:String):String
  {
    var result = ~/[^a-z0-9_-]+/g.replace(value.toLowerCase(), '-');
    if (result == '' || result == '-' || result == '.' || result == '..') throw 'Invalid mod/song ID';
    return result;
  }

  static function writeJson(path:String, value:Dynamic):Void
  {
    FileSystem.createDirectory(haxe.io.Path.directory(path));
    File.saveContent(path, Json.stringify(value));
  }
}
#end
