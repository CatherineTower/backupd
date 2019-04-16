private import BackupJob;
private import BackupFile;

private import std.path;
private import std.stdio;
private import std.datetime;
private import std.algorithm.sorting;

class BackupJobQueue {
public:

  BackupJob[] jobs;
  string configFileName;

  struct JobDurationWithPos {
    Duration duration;
    ulong index;

    int opCmp(JobDurationWithPos other) {
      return this.duration < other.duration;
    }
  }

  this(string configFileName) {
    this.configFileName = configFileName.expandTilde.absolutePath();

    auto configFile = File(this.configFileName, "r");
    foreach(line; configFile.byLine) {
      auto tmp = new BackupJob(line.idup);
      jobs ~= tmp;
    }
  }

  auto getQueuedJobTimes() const {
    JobDurationWithPos[] res;
    SysTime now = Clock.currTime();

    foreach(i, job; this.jobs) {
      /* Get the number of seconds until the job should be run */
      uint seconds = daysToDayOfWeek(now.dayOfWeek, job.dayOfWeek) * 24 * 3600;
      seconds += ((job.timeOfDay.hour * 3600) + (job.timeOfDay.minute * 60)
                  + job.timeOfDay.second);
      seconds -= ((now.hour * 3600) + (now.minute * 60) + now.second);

      JobDurationWithPos tmp;
      tmp.duration = dur!"seconds"(seconds);
      tmp.index = i;
      res ~= tmp;
    }

    return res.sort();
  }
}

unittest {
  auto jobs = new BackupJobQueue("~/.backupconfig");
  foreach(job; jobs.jobs) {
    write(job.configLine);
  }

  foreach(duration; jobs.getQueuedJobTimes) {
    writeln(duration.duration);
  }
}
