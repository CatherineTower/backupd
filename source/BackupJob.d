/* TODO: edit most of these to be local imports. The namespace feels
   suffocating, and I've heard that local imports are faster and take
   up less size in the finished executable */

private import std.datetime;
private import std.stdio;
private import std.path;
private import std.array : split;
private import std.string : strip;
private import std.exception;
private import std.file;

class BackupJob {
public:
  /* The main configuration file will be located in the home directory
     until further notice */
  static string backupConfigFileName = "~/.backupconfig";
  DayOfWeek dayOfWeek;
  TimeOfDay timeOfDay;

  enum RepeatInterval : ubyte { day, week, month, year }

  RepeatInterval repeatInterval;
  string outDirectoryRoot;
  string inDirectoryRoot;

  this() { }

  this(in string configLine) {
    this.parseLine(configLine);
  }

  void parseLine(in string configLine) {
    auto args = split(strip(configLine), '%');
    assert(args.length == 5);

    this.inDirectoryRoot = args[0].expandTilde.absolutePath.idup;
    this.outDirectoryRoot = args[1].expandTilde.absolutePath.idup;

    /* TODO: There's got to be a better (or more concise) way to do
       this */
    switch(args[2]) {
    default:
      assert(0);
    case "sun":
      this.dayOfWeek = DayOfWeek.sun;
      break;
    case "mon":
      this.dayOfWeek = DayOfWeek.mon;
      break;
    case "tue":
      this.dayOfWeek = DayOfWeek.tue;
      break;
    case "wed":
      this.dayOfWeek = DayOfWeek.wed;
      break;
    case "thu":
      this.dayOfWeek = DayOfWeek.thu;
      break;
    case "fri":
      this.dayOfWeek = DayOfWeek.fri;
      break;
    case "sat":
      this.dayOfWeek = DayOfWeek.sat;
      break;
    }

    this.timeOfDay = TimeOfDay.fromISOString(args[3]);

    /* TODO: Maybe factor this into its own function for
       readability */
    switch(args[4]) {
    default:
      assert(0);
    case "day":
      this.repeatInterval = BackupJob.RepeatInterval.day;
      break;
    case "week":
      this.repeatInterval = BackupJob.RepeatInterval.week;
      break;
    case "month":
      this.repeatInterval = BackupJob.RepeatInterval.month;
      break;
    case "year":
      this.repeatInterval = BackupJob.RepeatInterval.year;
      break;
    }
  }

  string configLine() const @property {
    import std.format : format;
    return format("%s%%%s%%%s%%%s%%%s\n", inDirectoryRoot, outDirectoryRoot,
                  dayOfWeek, timeOfDay.toISOString, repeatInterval);
  }

  void doBackup() {
    auto inEntries = generateEntries(inDirectoryRoot);
    auto outEntries = generateEntries(outDirectoryRoot);

    foreach(file; inEntries) {
      string outPath = outDirectoryRoot ~ relativePath(file.name, inDirectoryRoot);
      auto tmp = file.name in outEntries;
      if(tmp is null) {
        file.isDir ? mkdir(outPath) : copy(file.name, outPath);
      } else {
        if(tmp.timeLastModified > file.timeLastModified) {
          copy(file.name, outPath);
        }
      }
    }

    foreach(file; outEntries) {
      auto tmp = file in inEntries;
      if(file is null) {
        remove(file.name);
      }
    }
  }

private:
  DirEntry[string] generateEntries(in string path) {
    DirEntry[string] res;
    foreach(file; dirEntries(path, SpanMode.breadth, false)) {
      res[relativePath(file.name, path)] = file;
    }
    return res;
  }
}

unittest {
  try {
    /* Test that one can be instantiated at all */
    auto job = new BackupJob;
    job.inDirectoryRoot = "/home/calvin/src/timesheet";
    job.outDirectoryRoot = "/home/calvin/backuptest";
    job.repeatInterval = BackupJob.RepeatInterval.week;
    job.dayOfWeek = DayOfWeek.thu;
    job.timeOfDay = TimeOfDay(10, 0, 0);

    /* Test the backup algorithm */
    job.doBackup();

    /* Test parsing a config string which is output from an existing
       instance */
    auto duplicateJob = new BackupJob(job.configLine);
    assert(duplicateJob.inDirectoryRoot == job.inDirectoryRoot);
    assert(duplicateJob.outDirectoryRoot == job.outDirectoryRoot);
    assert(duplicateJob.repeatInterval == job.repeatInterval);
    assert(duplicateJob.dayOfWeek == job.dayOfWeek);
    assert(duplicateJob.timeOfDay == job.timeOfDay);

    auto job3 = new BackupJob("/home/calvin/src/timesheet%/home/calvin/backuptest"
                              ~ "%sun%000000%month");
    auto job4 = new BackupJob("/home/calvin/src/timesheet%/home/calvin/backuptest"
                              ~ "%sun%053000%day");
    /* Use this one for testing the daemon */
    auto job5 = new BackupJob(job.configLine);
    job5.dayOfWeek = DayOfWeek.wed;
    job5.timeOfDay = TimeOfDay(14, 7, 0);

    /* Collect the jobs into an array, for easier testing */
    BackupJob[] createdJobs;
    createdJobs ~= job;
    createdJobs ~= duplicateJob;
    createdJobs ~= job3;
    createdJobs ~= job4;
    createdJobs ~= job5;

    /* Write a simple configuration file */
    auto configFile
      = File(BackupJob.backupConfigFileName.expandTilde.absolutePath, "w");
    foreach(tmp; createdJobs) {
      configFile.write(tmp.configLine);
    }
    configFile.close();

    /* Read the configuration file */
    configFile
      = File(BackupJob.backupConfigFileName.expandTilde.absolutePath, "r");
    BackupJob[] readJobs;
    foreach(line; configFile.byLine) {
      readJobs ~= new BackupJob(line.idup);
    }

    /* Make sure they're the same as what was written */
    foreach(i, tmp; readJobs) {
      assert(readJobs[i].configLine == createdJobs[i].configLine);
      assert(readJobs[i].inDirectoryRoot == createdJobs[i].inDirectoryRoot);
      assert(readJobs[i].outDirectoryRoot == createdJobs[i].outDirectoryRoot);
      assert(readJobs[i].repeatInterval == createdJobs[i].repeatInterval);
      assert(readJobs[i].dayOfWeek == createdJobs[i].dayOfWeek);
      assert(readJobs[i].timeOfDay == createdJobs[i].timeOfDay);
    }


  } catch(Exception e) {
    writeln("THIS ERROR WAS CAUGHT AT THE END OF THE UNITTEST BLOCK");
    writefln("Line %s", e.line);
    writefln("Message: %s", e.msg);
  }
}
