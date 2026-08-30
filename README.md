
## Overview & Architecture

This project implements a reliable transport layer built directly on top of raw UDP sockets (`SOCK_DGRAM`) in C[cite: 2]. By layering sequence tracking, dynamic flow control, and automated retransmissions over connectionless datagrams, it provides TCP-like stream reliability through custom socket APIs (`k_socket`, `k_bind`, `k_sendto`, `k_recvfrom`, `k_close`)[cite: 2].

The system architecture runs via a central daemon initializer process (`initksocket.c`) that maintains a Shared Socket Table and spawns concurrent worker threads to manage network I/O asynchronously alongside user-space application processes (`user1.c`, `user2.c`)[cite: 2].


```

+-----------------------------------------------------------------------+
|                       User Application Layer                          |
|                  (user1.c / user2.c using ksocket API)                |
+-----------------------------------------------------------------------+
|                                                     ^
| k_sendto() / k_recvfrom()                           | Shared Memory
v                                                     v Synchronization
+-----------------------------------------------------------------------+
|                     Shared Socket Table & Buffers                     |
|                  (System V Shared Memory + Semaphores)                |
+-----------------------------------------------------------------------+
|                                                     ^
| Producer / Consumer Queue                           | Shared Memory
v                                                     v Access
+-----------------------------------------------------------------------+
|                   Daemon Manager Process (initksocket)                |
|  +---------------------------------+  +----------------------------+  |
|  |   Sender Thread (S)             |  |  Receiver Thread (R)       |  |
|  |   - Timeout Management          |  |  - In-Order Reassembly     |  |
|  |   - Flow Control Window (N)     |  |  - ACK Generation          |  |
|  +---------------------------------+  +----------------------------+  |
+-----------------------------------------------------------------------+
|                                                     ^
| sendto() (UDP Datagram)                             | recvfrom() (UDP)
v                                                     |
+-----------------------------------------------------------------------+
|                         Physical Network / UDP                        |
+-----------------------------------------------------------------------+

```

---

## Operating System & IPC Concepts

* **Shared Memory Inter-Process Communication (`shmget`, `shmat`):** Establishes a shared memory block containing socket tables and message ring buffers shared between user processes and the daemon (`initksocket.c`)[cite: 2]. Enables zero-copy data passing between application threads and background transport threads[cite: 2].
* **System V Semaphore Synchronization (`semget`, `semop`):** Enforces mutual exclusion (`Mutex`) across shared socket structures to prevent race conditions during concurrent buffer reads and writes[cite: 2]. Provides conditional signaling (`P`/`V` operations) to suspend execution when send buffers are full or receive buffers are empty, waking processes up upon ACK processing or data arrival[cite: 2].
* **Multithreaded Asynchronous I/O:** 
  * **Sender Thread (`S`):** Scans the send window, handles packet timeouts, updates sequence counters, and retransmits unacknowledged frames[cite: 2].
  * **Receiver Thread (`R`):** Listens on the underlying UDP socket, filters out-of-order packets, updates receive window states, and transmits cumulative ACK frames back to the sender[cite: 2].
* **Non-Blocking Network I/O Multiplexing:** Utilizes `select()` / `poll()` socket monitoring to process network events without blocking the daemon main loop[cite: 2].

---

## Network Protocols, Flow Control & Reliability

* **Sliding Window Flow Control:** Implements a sliding window mechanism ($N$) to adjust payload delivery dynamically, matching sender rate to receiver buffer capacity and avoiding overflow.
* **Sequence & ACK Tracking:** Header structures carry explicit sequence numbers and acknowledgment numbers to reassemble datagram payloads in order and verify data integrity.
* **Retransmission & Timeout Strategy:** Features timer-driven packet management to catch lost datagrams or dropped acknowledgments, automatically resending unacknowledged packets to maintain reliability over unreliable networks.
* **Corrupted Frame Rejection:** Validates incoming datagram integrity, dropping damaged payloads and triggering timeout-driven retransmissions.

---

## System Workflow


```

User Process (Sender)        Sender Thread (S)          Receiver Thread (R)      User Process (Receiver)
|                             |                            |                            |
|--- k_sendto(Data)---------->|                            |                            |
|    (Writes to Shared Mem)   |                            |                            |
|                             |--- UDP Datagram (Seq X)--->|                            |
|                             |                            |--- (Validates & Enqueues)->|
|                             |                            |                            |--- k_recvfrom()
|                             |<-- UDP ACK (Ack X)---------|                            |
|                             |                            |                            |
|                             | (Updates Window/Frees Mem) |                            |
v                             v                            v                            v

```

```
