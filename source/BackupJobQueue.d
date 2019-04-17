private import BackupJob;
private import BackupFile;

private import std.path;
private import std.stdio;
private import std.datetime;

class BackupJobQueue {
public:

  BackupJob[] jobs;
  string configFileName;

  struct JobDurationWithPos {
    Duration duration;
    ulong index;

    this(Duration duration, ulong index) {
      this.duration = duration;
      this.index = index;
    }

    int opCmp(JobDurationWithPos other) const pure {
      return this.duration < other.duration;
    }
  }

  this(in string configFileName) {
    this.configFileName = configFileName.expandTilde.absolutePath();

    auto configFile = File(this.configFileName, "r");
    foreach(line; configFile.byLine) {
      auto tmp = new BackupJob(line.idup);
      jobs ~= tmp;
    }
  }

  auto getNextJobTime() const {
    JobDurationWithPos[] res;
    SysTime now = Clock.currTime();

    foreach(i, job; this.jobs) {
      /* Get the number of seconds until the job should be run */
      uint seconds = daysToDayOfWeek(now.dayOfWeek, job.dayOfWeek) * 24 * 3600;
      seconds += ((job.timeOfDay.hour * 3600) + (job.timeOfDay.minute * 60)
                  + job.timeOfDay.second);
      seconds -= ((now.hour * 3600) + (now.minute * 60) + now.second);

      res ~= JobDurationWithPos(dur!"seconds"(seconds), i);
    }

    import std.algorithm.searching : minElement;
    return res.minElement();
  }
}

unittest {
  auto jobs = new BackupJobQueue("~/.backupconfig");
  foreach(job; jobs.jobs) {
    write(job.configLine);
  }

  writeln("Next backup: ", jobs.getNextJobTime().duration,
          " job number: ", jobs.getNextJobTime.index);
}
