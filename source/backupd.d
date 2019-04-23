import BackupJob;
import BackupJobQueue;

import core.thread;
import std.stdio;

enum string programName = "backupd";

int main(string[] args) {

  parseArguments(args);

  auto jobs = new BackupJobQueue("~/.backupconfig");
  while(1) {
    auto nextJob = jobs.getNextJobTime();
    Thread.sleep(nextJob.duration);

    jobs[nextJob.index].doBackup();
    /* In the event that there's nothing to back up and it's a small
       directory tree, it will run the job multiple times. This is to
       prevent such redundancy */
    Thread.sleep(dur!"seconds"(1));
  }
}

void parseArguments(string[] args) {
  if(args.length == 1) {
    return;
  }

  import core.stdc.stdlib : exit;
  foreach(arg; args) {
    if(arg == "-l" || arg == "--list") {
      auto jobs = new BackupJobQueue(BackupJob.BackupJob.backupConfigFileName);
      writeln(jobs);
      exit(0);
    }
  }
  stderr.writeln("Error: no known arguments passed");
  exit(1);
}

void usage(int status) {
  writefln("Usage: %s [OPTIONS]\n", programName);
  writeln("OPTIONS:");
  writeln(" -n  --new      Create a new backup job");
  writeln(" -l  --list     List existing backup jobs");

  import core.stdc.stdlib : exit;
  exit(status);
}
