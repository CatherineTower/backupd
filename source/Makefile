DC = dmd

SOURCES = backupd.d BackupFile.d BackupJob.d BackupJobQueue.d
DFLAGS = -de -w

TEST_SOURCES = BackupFile.d BackupJob.d BackupJobQueue.d
TEST_DFLAGS = -de -w -main -unittest

daemon: $(SOURCES)
	$(DC) $(DFLAGS) -of=backupd $(SOURCES)

test: $(TEST_SOURCES)
	$(DC) $(TEST_DFLAGS) -of=BackupUnitTest $(TEST_SOURCES)
	./BackupUnitTest

.PHONY:clean
clean:
	rm -rf BackupUnitTest backupd *.o
