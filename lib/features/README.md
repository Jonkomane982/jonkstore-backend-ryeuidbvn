# Features Layer
This directory follows a **Feature-First** approach. Each feature is self-contained and follows **Clean Architecture** principles.

## Internal Feature Structure:
- **data/**: Data sources (APIs, Local DB) and repository implementations.
- **domain/**: Business logic, Entities, and Use Case definitions.
- **presentation/**: UI logic and state management.
- **widgets/**: Feature-specific reusable UI components.
- **pages/**: Full-screen view components.
- **controllers/**: State management (Riverpod/BLoC/GetX).
- **repositories/**: Abstract interfaces defining the data contract.
