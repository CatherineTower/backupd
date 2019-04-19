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

    /* THIS IS FOR DEBUGGING */
    writefln("Doing job %s", nextJob.index);
    /* TAKE IT OUT LATER */

    jobs[nextJob.index].doBackup();
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
