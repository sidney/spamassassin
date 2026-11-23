/* alarmtest ITERS FORKEVERY: alarm(64), short sleep, alarm(0), alarm(0);
   the second alarm(0), and the next alarm(64), must return 0.
   FORKEVERY > 0 forks a child every FORKEVERY iterations that sets
   and clears its own alarms and exits. */
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t alrm;
static void onalrm(int s) { (void)s; alrm++; }
static void onchld(int s) {
  int e = errno; (void)s;
  while (waitpid(-1, NULL, WNOHANG) > 0) ;
  errno = e;
}

int main(int argc, char **argv) {
  int iters = argc > 1 ? atoi(argv[1]) : 5000;
  int forkevery = argc > 2 ? atoi(argv[2]) : 0;
  struct sigaction sa;
  int i, j, bad = 0;
  memset(&sa, 0, sizeof sa);
  sa.sa_handler = onalrm; sigaction(SIGALRM, &sa, NULL);
  sa.sa_handler = onchld; sa.sa_flags = SA_RESTART; sigaction(SIGCHLD, &sa, NULL);
  srandom(getpid());
  for (i = 0; i < iters; i++) {
    unsigned r0, r1, r2;
    if (forkevery && i % forkevery == 0) {
      if (fork() == 0) {
        for (j = 0; j < 20; j++) {
          alarm(1 + random() % 300); usleep(random() % 5000); alarm(0);
        }
        _exit(0);
      }
    }
    r0 = alarm(64);
    usleep(random() % 3000);
    r1 = alarm(0);
    r2 = alarm(0);
    if (r0 || r2 || !r1) {
      bad++;
      printf("pid %d iter %d: alarm(64) returned %u, then alarm(0) %u, alarm(0) %u\n",
             (int)getpid(), i, r0, r1, r2);
      fflush(stdout);
    }
  }
  printf("pid %d done: %d iterations, fork every %d, %d anomalies, %d SIGALRM\n",
         (int)getpid(), iters, forkevery, bad, (int)alrm);
  return 0;
}
