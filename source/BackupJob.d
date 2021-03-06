/* TODO: edit most of these to be local imports. The namespace feels
   suffocating, and I've heard that local imports are faster and take
   up less size in the finished executable */

private import std.datetime;
private import std.stdio;
private import std.path;
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
    import std.array : split;
    import std.string : strip;
    auto args = split(strip(configLine), '\t');
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
    return format("%s\t%s\t%s\t%s\t%s\n", inDirectoryRoot, outDirectoryRoot,
                  dayOfWeek, timeOfDay.toISOString, repeatInterval);
  }

  void doBackup() {
    auto inEntries = generateEntries(inDirectoryRoot);
    auto outEntries = generateEntries(outDirectoryRoot);

    foreach(file; inEntries) {
      if(file.isDir) {
        continue;
      }

      string outPath = outDirectoryRoot ~
        "/" ~ relativePath(file.name, inDirectoryRoot);

      auto tmp = file.name in outEntries;
      try {
        if(tmp is null) {
          /* File doesn't exist */
          try {
            /* If the parent directory doesn't exist, this will fail. */
            file.isDir ? mkdir(outPath) : copy(file.name, outPath);
          } catch(FileException e) {
            /* So make the parent directory and try copying again */
            mkdirRecurse(dirName(outPath));
            copy(file.name, outPath);
          }
        } else {
          /* Only copy a file that's been modified */
          if(tmp.timeLastModified > file.timeLastModified) {
            copy(file.name, outPath);
          }
        }
      } catch(Exception e) {
        stderr.writeln(e.msg);
        continue;
      }
    }

    /* I tested this with an in-memory data structure instead of
    re-reading from disk, and there was no appreciable speedup; most
    of the spent here likely comes from the creation of files */
    foreach(file; dirEntries(outDirectoryRoot, SpanMode.depth, false)) {
      try {
        auto tmp = relativePath(file.name, outDirectoryRoot) in inEntries;
        if(tmp is null) {
          remove(file.name);
        }
      } catch(Exception e) {
        stderr.writeln(e.msg);
        continue;
      }
    }
  }

  override string toString() const {
    import std.format : format;
    return format("%s %s, repeating every %s\n", this.timeOfDay, this.dayOfWeek,
                  this.repeatInterval);
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
    /* Test to make sure avoiding copying unchanged files works */
    job.doBackup();

    /* Test parsing a config string which is output from an existing
       instance */
    auto duplicateJob = new BackupJob(job.configLine);
    assert(duplicateJob.inDirectoryRoot == job.inDirectoryRoot);
    assert(duplicateJob.outDirectoryRoot == job.outDirectoryRoot);
    assert(duplicateJob.repeatInterval == job.repeatInterval);
    assert(duplicateJob.dayOfWeek == job.dayOfWeek);
    assert(duplicateJob.timeOfDay == job.timeOfDay);

    auto job3 = new BackupJob("/home/calvin/src/timesheet\t/home/calvin/backuptest"
                              ~ "\tsun\t000000\tmonth");
    auto job4 = new BackupJob("/home/calvin/src/timesheet\t/home/calvin/backuptest"
                              ~ "\tsun\t053000\tday");
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

    /* Test that the backup algorithm will properly handle files that
       aren't in the destination directory. At the end of this test,
       the destination directory shouldn't contain any files from the
       original source directory */
    auto replacementJob = new BackupJob();
    replacementJob.inDirectoryRoot = "/home/calvin/src/emacs";
    replacementJob.outDirectoryRoot = "/home/calvin/backuptest/";
    replacementJob.doBackup();

  } catch(Exception e) {
    writeln("THIS ERROR WAS CAUGHT AT THE END OF THE UNITTEST BLOCK");
    writefln("Line %s", e.line);
    writefln("Message: %s", e.msg);
  }
}
