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

  BackupJob opIndex(size_t index) {
    return jobs[index];
  }

  auto getNextJobTime() const {
    JobDurationWithPos[] res;
    SysTime now = Clock.currTime();

    foreach(i, job; this.jobs) {
      /* Get the number of seconds until the job should be run */
      ulong seconds = daysToDayOfWeek(now.dayOfWeek, job.dayOfWeek);
      seconds = seconds == 0 ? 7 : seconds;
      seconds *= (24 * 3600);
      seconds += ((job.timeOfDay.hour * 3600) + (job.timeOfDay.minute * 60)
                  + job.timeOfDay.second);
      seconds -= ((now.hour * 3600) + (now.minute * 60) + now.second);

      assert(res.length == i);
      res ~= JobDurationWithPos(dur!"seconds"(seconds), i);
    }
    assert(res.length == this.jobs.length);

    import std.algorithm.searching : minElement;
    foreach(el; res) {
      writeln(el);
      writeln(res.minElement);
      assert(res.minElement <= el);
    }
    return res.minElement();
  }
}

unittest {
  auto jobs = new BackupJobQueue("~/.backupconfig");

  writeln("Next backup: ", jobs.getNextJobTime().duration,
          " job number: ", jobs.getNextJobTime.index);
}
