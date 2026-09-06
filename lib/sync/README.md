# JonkStore POS - Offline Synchronization Architecture

This document explains the technical architecture for synchronizing the local SQLite database with the remote PostgreSQL backend.

## 🔄 Synchronization Flow

### 1. How SQLite syncs to PostgreSQL
The architecture uses a **Queue-Based Eventual Consistency** model.
*   **Local-First**: All data is first written to SQLite.
*   **Sync Queue**: Every write operation (Create, Update, Delete) triggers a `SyncTask` entry in the `sync_queue` table.
*   **Sync Engine**: The engine processes tasks in the background when connectivity is available.
*   **Push**: The `SyncEngine` reads the queue and sends data to the Node.js REST API using the `ApiClient`.
*   **Pull**: Repositories periodically fetch delta changes from the server (using `last_synced_at` timestamp) and merge them into SQLite.

### 2. How Updates are handled
*   When a record is updated locally, its `sync_status` is set to `SyncStatus.updated`.
*   A `SyncTask` with operation `UPDATE` is added to the queue.
*   The remote API receives the update and applies it to PostgreSQL.
*   Upon success, the local `sync_status` transitions to `SyncStatus.synced`.

### 3. How Deletions are handled
*   JonkStore POS uses **Soft Deletions**.
*   Records are not immediately removed from SQLite. Instead, `sync_status` is set to `SyncStatus.deleted`.
*   The `SyncEngine` notifies the server to delete the record in PostgreSQL.
*   Only after the server confirms deletion is the record physically removed from SQLite (or marked as inactive).

### 4. How Conflicts are resolved
Conflicts occur when the same record is modified both locally and on the server between sync cycles.
*   **Version Tracking**: Every entity has an `updatedAt` timestamp.
*   **Resolver Strategy**: The `ConflictResolver` interface allows for multiple strategies.
*   **Default (Last-Write-Wins)**: The record with the most recent `updatedAt` timestamp is kept.
*   **UI Intervention**: For critical entities (like Sales), the system can flag a `SyncState.conflict` and prompt the user to choose which version to keep.

### 5. How Retries work
Network failures are common in POS environments.
*   **Exponential Backoff**: The `SyncScheduler` and `SyncEngine` implement retry logic.
*   **Retry Limit**: Tasks in the `sync_queue` have a `retryCount`. If a task fails more than 3 times, it is marked as `SyncState.failed` and moved to a "Manual Review" state to prevent infinite loops and data corruption.
*   **Connectivity Awareness**: The `SyncManager` listens to system connectivity events. Syncing only resumes when `ConnectivityResult` is not `none`.

## 🛠 Architectural Components

*   `SyncEngine`: The orchestrator that processes the queue.
*   `SyncQueue`: Persistent storage for tasks waiting to be synced.
*   `SyncWorker`: Entity-specific logic for pushing/pulling data.
*   `SyncManager`: High-level service that reacts to network changes.
*   `SyncScheduler`: Handles periodic background synchronization.
