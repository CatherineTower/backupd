private import BackupFile;
private import std.datetime;
private import std.stdio;
private import std.path;
private import std.array : split;
private import std.string : strip;
private import std.exception;

class BackupJob {
public:
  /* The main configuration file will be located in the home directory
     until further notice */
  static string backupConfigFileName = "~/.backupconfig";
  BackupFile backupFile;
  DayOfWeek dayOfWeek;
  TimeOfDay timeOfDay;

  enum RepeatInterval : ubyte {
    day, week, month, year
  }

  RepeatInterval repeatInterval;
  string outDirectoryRoot;
  string inDirectoryRoot;

  this() {
    this.backupFile = new BackupFile;
  }

  this(string configLine) {
    this.parseLine(configLine);

    try {
      this.backupFile = new BackupFile(this.outDirectoryRoot ~ "/"
                                       ~ backupFile.backupFileListName);
    } catch (ErrnoException e) {
      stderr.writeln(e.msg);
      /* Backup file list doesn't exist */
      writeln("Creating file list...");
      this.backupFile = new BackupFile();
      this.backupFile.generateEntries(this.inDirectoryRoot);
      this.backupFile.writeFile(this.outDirectoryRoot ~ "/" ~
                                backupFile.backupFileListName);
    }
  }

  void parseLine(string configLine) {
    auto args = split(strip(configLine), '%');
    assert(args.length == 5);

    this.inDirectoryRoot = args[0].expandTilde.absolutePath.dup;
    this.outDirectoryRoot = args[1].expandTilde.absolutePath.dup;

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
}

unittest {
  try {
    /* Test that one can be instantiated at all */
    auto job = new BackupJob;
    job.inDirectoryRoot = "/home/calvin/src/timesheet";
    job.outDirectoryRoot = "/home/calvin/backuptest";
    job.repeatInterval = BackupJob.RepeatInterval.week;
    job.dayOfWeek = DayOfWeek.wed;
    job.timeOfDay = TimeOfDay(20, 0, 0);

    /* Test parsing a config string which is output from an existing
       instance */
    auto duplicateJob = new BackupJob(job.configLine);
    assert(duplicateJob.inDirectoryRoot == job.inDirectoryRoot);
    assert(duplicateJob.outDirectoryRoot == job.outDirectoryRoot);
    assert(duplicateJob.repeatInterval == job.repeatInterval);
    assert(duplicateJob.dayOfWeek == job.dayOfWeek);
    assert(duplicateJob.timeOfDay == job.timeOfDay);

  } catch(Exception e) {
    writeln("THIS ERROR WAS CAUGHT AT THE END OF THE UNITTEST BLOCK");
    writefln("Line %s", e.line);
    writefln("Message: %s", e.msg);
  }
}
