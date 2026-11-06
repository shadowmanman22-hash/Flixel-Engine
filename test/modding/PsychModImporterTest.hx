import funkin.modding.PsychModImporter;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class PsychModImporterTest
{
  static function check(ok:Bool, message:String):Void
  {
    if (!ok) throw message;
  }

  static function main():Void
  {
    var song:Dynamic = {
      song: 'Test',
      bpm: 120,
      speed: 1.5,
      notes: [
        {
          mustHitSection: false,
          sectionNotes: [[100, 0, 0], [200, 4, 150]]
        },
        {
          mustHitSection: true,
          sectionNotes: [[2100, 1, 0], [2200, 5, 0]]
        },
        {
          mustHitSection: true,
          changeBPM: true,
          bpm: 150,
          sectionNotes: [],
          sectionBeats: 3
        },
        {
          mustHitSection: false,
          sectionNotes: [[5300, 0, 0]]
        }
      ]
    };
    var chart = PsychModImporter.convertChart(song);
    check(chart.notes[0].d == 4 && chart.notes[1].d == 0, 'opponent section ownership');
    check(chart.notes[2].d == 1 && chart.notes[3].d == 5, 'player section ownership');
    check(chart.notes[1].l == 150, 'sustain duration');
    check(chart.timeChanges[1].t == 4000, 'BPM changes occur at section start, even for empty sections');
    check(chart.events[2].t == 5200, 'variable sectionBeats and BPM');
    var invalid = Json.parse(Json.stringify(song));
    invalid.notes[0].sectionNotes[0][3] = 'Hurt Note';
    var rejected = false;
    try
      PsychModImporter.convertChart(invalid)
    catch (e:Dynamic)
      rejected = true;
    check(rejected, 'custom notes must not silently become normal notes');

    var root = Sys.getEnv('PSYCH_TEST_ROOT');
    if (root == null) throw 'Set PSYCH_TEST_ROOT to a disposable directory';
    FileSystem.createDirectory('$root/source/data/test');
    FileSystem.createDirectory('$root/source/songs/test');
    File.saveContent('$root/source/data/test/test.json', Json.stringify({
      song: song
    }));
    File.saveContent('$root/source/data/test/test-hard.json', '{invalid JSON');
    var cameraMismatch = Json.parse(Json.stringify(song));
    cameraMismatch.notes[1].mustHitSection = false;
    File.saveContent('$root/source/data/test/test-easy.json', Json.stringify({
      song: cameraMismatch
    }));
    File.saveContent('$root/source/songs/test/Inst.ogg', 'test-instrumental');
    File.saveContent('$root/source/songs/test/Voices.ogg', 'test-vocals');
    File.saveContent('$root/source/songs/test/Voices-Player.ogg', 'test-player');
    File.saveContent('$root/source/songs/test/Voices-Opponent.ogg', 'test-opponent');
    check(PsychModImporter.importPack('$root/source', '$root/mods/psych-test') == 1, 'import pack');
    var metadata = Json.parse(File.getContent('$root/mods/psych-test/data/songs/psych-test-test/psych-test-test-metadata.json'));
    check(metadata.playData.difficulties.length == 1 && metadata.playData.difficulties[0] == 'normal',
      'normal preferred, invalid or mismatched difficulties isolated'
    );
    check(File.getContent('$root/mods/psych-test/songs/psych-test-test/Voices-bf.ogg') == 'test-player', 'player voices mapped');
    check(File.getContent('$root/mods/psych-test/songs/psych-test-test/Voices-dad.ogg') == 'test-opponent', 'opponent voices mapped');
    check(FileSystem.exists('$root/mods/psych-test/data/levels/psych-test.json'), 'Freeplay level published');
    check(File.getContent('$root/mods/psych-test/songs/psych-test-test/Inst.ogg') == 'test-instrumental', 'audio copied unchanged');
    check(FileSystem.exists('$root/mods/psych-test/_polymod_meta.json'), 'published Polymod metadata');
    check(FileSystem.exists('$root/source/data/test/test.json'), 'source preserved');
    check(!FileSystem.exists('$root/mods/psych-test.importing'), 'staging published');
    rejected = false;
    try
      PsychModImporter.importPack('$root/source', '$root/mods/psych-test')
    catch (e:Dynamic)
      rejected = true;
    check(rejected, 'existing mod is never overwritten');
    // Failed imports must leave no installed pack and remain retryable.
    FileSystem.createDirectory('$root/broken/data');
    check(PsychModImporter.importPack('$root/broken', '$root/mods/psych-broken') == 0, 'empty pack is not installed');
    check(!FileSystem.exists('$root/mods/psych-broken') && !FileSystem.exists('$root/mods/psych-broken.importing'), 'failed import is cleaned up');
    FileSystem.createDirectory('$root/broken/data/test');
    FileSystem.createDirectory('$root/broken/songs/test');
    File.saveContent('$root/broken/data/test/test.json', Json.stringify({
      song: song
    }));
    File.saveContent('$root/broken/songs/test/Inst.ogg', 'test-instrumental');
    check(PsychModImporter.importPack('$root/broken', '$root/mods/psych-broken') == 1, 'retry after correcting the source');
    // Invalid directory names must not prevent Polymod/game startup.
    FileSystem.createDirectory('$root/packs/!!!');
    PsychModImporter.importAll('$root/packs', '$root/mods');
    PsychModImporter.importAll('$root/missing', '$root/mods');
    Sys.println('Psych importer tests passed');
  }
}
