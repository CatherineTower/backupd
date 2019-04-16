import BackupJob;
import BackupJobQueue;
import BackupFile;

import core.thread;

int main(string[] args) {

  auto jobs = new BackupJobQueue("~/.backupconfig");
  while(1) {
    auto durations = jobs.getQueuedJobTimes();
    foreach(entry; durations) {
      Thread.sleep(entry.duration);
      jobs.jobs[entry.index].doBackup();
    }
  }
}
