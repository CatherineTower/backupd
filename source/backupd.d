import BackupJob;
import BackupJobQueue;
import BackupFile;

import core.thread;
import std.stdio;

enum string programName = "backupd";

int main(string[] args) {

  parseArguments(args);

  auto jobs = new BackupJobQueue("~/.backupconfig");
  while(1) {
    auto durations = jobs.getQueuedJobTimes();
    foreach(entry; durations) {
      Thread.sleep(entry.duration);

      /* THIS IS FOR DEBUGGING */
      writefln("Doing job %s", entry.index);
      /* TAKE IT OUT LATER */

      jobs.jobs[entry.index].doBackup();
    }
  }
}

void parseArguments(string[] args) {

}

void usage(int status) {
  writefln("Usage: %s [OPTIONS]\n", programName);
  writeln("OPTIONS:");
  writeln(" -n  --new      Create a new backup job");
  writeln(" -l  --list     List existing backup jobs");

  import core.stdc.stdlib : exit;
  exit(status);
}
