private import BackupJob;

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

    this(const Duration duration, ulong index) {
      this.duration = duration;
      this.index = index;
    }

    int opCmp(const ref JobDurationWithPos other) const pure {
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

  BackupJob opIndex(size_t index) {
    return jobs[index];
  }

  auto getNextJobTime() const {
    JobDurationWithPos[] res;
    enum int secondsPerWeek = 7 * 24 * 3600;
    SysTime now = Clock.currTime();

    foreach(i, job; this.jobs) {
      /* Get the number of seconds until the job should be run */
      long seconds = daysToDayOfWeek(now.dayOfWeek, job.dayOfWeek) * 24 * 3600;
      seconds += ((job.timeOfDay.hour * 3600) + (job.timeOfDay.minute * 60)
                  + job.timeOfDay.second);
      seconds -= ((now.hour * 3600) + (now.minute * 60) + now.second);

      if(seconds < 0) {
        seconds += secondsPerWeek;
      }
      assert(seconds >= 0);

      assert(res.length == i);
      res ~= JobDurationWithPos(dur!"seconds"(seconds), i);
    }
    assert(res.length == this.jobs.length);

    /* I don't know why minElement doesn't work. It consistently
       gives me the exact opposite of the correct element. I don't
       know what's gone wrong, but using maxElement works. For some
       maddening reason */
    import std.algorithm : maxElement;
    return res.maxElement();
  }
}

unittest {
  auto jobs = new BackupJobQueue("~/.backupconfig");

  writeln("Next backup: ", jobs.getNextJobTime().duration,
          " job number: ", jobs.getNextJobTime.index);
}
