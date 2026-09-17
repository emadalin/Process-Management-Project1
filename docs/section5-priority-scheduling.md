# Demo Section 5: Priority / Scheduling (5 min)

Owner: Member 5 (Sarah Rae & Calli). Presented at rehearsal by Georgia.

**One-sentence version:** Quality of Service changes how much CPU time a thread tends to get and which cores it may use, but it is a request to macOS, not a guarantee of execution order.

---

## 1. What our test does (`Sources/ThreadLab/PriorityTest.swift`)

- **Three identical racers:** `PickerRobot1`, `PickerRobot2`, and `PickerRobot3` run the same CPU-bound loop, counting iterations until a shared 2-second deadline. The loop has no printing, locking, or sleeping.
- **Contention without pinning:** macOS can't pin threads to cores, so we add one `LoadThread` per logical core running the same loop. On an 8-core M2 that makes 11 busy threads for 8 cores, so the threads really compete.
- **No head start:** every thread waits at a `StartGate` (built on `NSCondition`). When all threads are ready, the gate opens and gives them one shared deadline. We measure **work done in a fixed time**, not who printed first, so the thread started first gets no advantage.
- **Two configurations:**
  1. **All `.default`:** QoS is never set, so each thread keeps macOS's default.
  2. **`.userInteractive` / `.utility` / `.background`:** set on `PickerRobot1`, `2`, and `3` **before** `start()`. Load threads stay at the default in both configurations.
- **Five runs per configuration**, alternating between the two with a 1-second cooldown, so heat and background activity don't favor one configuration.
- **Requested vs. actually applied:** inside each racer we read `Thread.current.qualityOfService`, `Thread.current.threadPriority`, and `qos_class_self()`. Results go into a lock-protected `ResultsStore` and are printed only after every thread has finished.
- **Machine details every run:** the test prints chip, core counts (performance vs. efficiency), macOS version, debug vs. release, Low Power Mode, and thermal state.

**Run it:** `swift run -c release ThreadLab priority`. This works once Member 2's mode switch calls `runPriorityTest()`.

---

## 2. Quality of Service vs. `threadPriority` (practice question 14)

| | Quality of Service | `threadPriority` |
|---|---|---|
| What you say | *What kind of work* this is | A number from 0.0 to 1.0 |
| What macOS does with it | Picks scheduling priority, **which core types** the thread may use, and CPU / I/O throttling | Maps it to a kernel priority, with no guarantee of how |
| Apple's position | Preferred mechanism | `NSThread.h`: "To be deprecated; use qualityOfService" |

QoS classes, highest to lowest:
- `.userInteractive`: UI and animation.
- `.userInitiated`: work the user is waiting on.
- `.default`
- `.utility`: long-running work with progress.
- `.background`: work the user doesn't see.

**Evidence from our output:** every racer reports `threadPriority: 0.50`, whether its QoS is `.userInteractive` or `.background`. The two are separate controls. Changing QoS doesn't show up in `threadPriority`, but it does change `qos_class_self()` and the work done.

## 3. Why QoS must be set before `start()` (practice question 15)

The macOS SDK header `NSThread.h` says `qualityOfService` is **"read-only after the thread is started."** The QoS is applied when the underlying thread is created, so our code sets `thread.qualityOfService` before `thread.start()`. Inside the thread, `qos_class_self()` confirms the kernel applied it.

## 4. Apple Silicon: performance vs. efficiency cores (practice question 16)

- Our M2 has **4 performance (P) cores and 4 efficiency (E) cores**.
- On Apple Silicon, macOS keeps `.background` work on the **efficiency cores**, and lower QoS classes are also more heavily throttled.
- So a `.background` thread can run much slower **even when nothing else is running**. That comes from core placement and throttling, not from waiting its turn in some fixed order.
- **Intel Macs:** all cores are the same type, so QoS differences are usually much smaller and mostly appear under heavy load. Results from different Macs aren't directly comparable (see `docs/machine-details.md`).

## 5. What macOS doesn't let us do (practice question 17)

- **No CPU pinning.** There's no equivalent of Linux's `taskset`. The thread-affinity API is only a hint on Intel and isn't supported on Apple Silicon. We created contention instead by running more CPU-bound threads (3 racers + 1 load thread per core) than there are cores.
- **No guaranteed ordering from priority.** QoS is a request that the kernel balances against every other thread on the machine.
- Real-time scheduling exists for audio/media workloads, but it isn't appropriate or needed here.

## 6. Does priority guarantee execution order? (practice question 7)

**No.** A higher QoS makes a thread *more likely* to get CPU time and a better core, but:
- the scheduler still preempts it and runs other threads;
- normal threads' effective priority can drop as they use a lot of CPU;
- the rest of the system (other apps, heat, battery state) affects what happens;
- lower-QoS threads still make progress. Our `.background` racer still counts millions of iterations, so it isn't simply made to wait until the others finish.

Say "tends to get more work done," never "runs first."

---

## 7. Results

Official clean run: Sarah Rae's Apple M2, plugged in, Low Power Mode off, heavy apps closed, release build, 5 runs per config. Every racer's `qos_class_self()` matched the QoS it requested. Full output: `output-priority-run2.txt`.

**Averages (% of the fastest racer in that config):**

| Machine | Config | Picker-1 | Picker-2 | Picker-3 |
|---|---|---|---|---|
| Apple M2 (4P / 4E) | All `.default` | 86,878,830 (98%) | 87,751,922 (99%) | 88,329,425 (100%) |
| Apple M2 (4P / 4E) | `.userInteractive` / `.utility` / `.background` | 101,635,936 (100%) | 40,375,553 (39%) | 8,994,427 (8%) |

All-`.default` racers finish within 2% of each other — no QoS difference, no advantage. Under mixed QoS, the `.userInteractive` racer keeps ~100% of the fastest pace while `.background` drops to single digits — QoS changes *how much* work gets done, not the order threads finish in.

For the Apple M3 Pro comparison (Calli's machine, Low Power Mode **on**, so hardware-comparison only, not the official evidence) and the full 5-run-per-config raw numbers on both machines, see [`project1-team-task.md`, Section 5](../project1-team-task.md#5-results-table). The same table is also in the [README](../README.md#priority-results).

## 8. Limitations of this test

- **Iteration counts aren't pure "work":** each iteration also reads the clock, so compare counts only against each other on the same Mac and build, not as absolute performance.
- **Debug vs. release:** debug builds do fewer iterations overall, so compare ratios between racers rather than raw counts across builds.
- **Noise:** battery vs. plugged in, Low Power Mode, heat, and other apps all change results, which is why we record them and run at least 5 times.
- **One Mac is one data point.** A different chip or core layout can give a different spread.

## Sources to cite
- `NSThread.h` in the macOS SDK: `qualityOfService` "read-only after the thread is started"; `threadPriority` "To be deprecated."
- Apple Developer Documentation: `QualityOfService`, `qos_class_self`, *Energy Efficiency Guide for Mac Apps: Prioritize Work with Quality of Service Classes*, *Tuning your code's performance for Apple silicon*.
- Project brief, Section 4.4.
