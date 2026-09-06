% Security Rules

% Rule: barcode_burst_pattern
% Detects unusual scanning frequency in a short window.
barcode_burst_pattern(Result, Evidence) :-
    get_fact(scan_count, Count),
    get_fact(window_seconds, Window),
    Count > 10,
    Window < 60,
    Result = 'INVESTIGATION_RECOMMENDED',
    Evidence = json([scans=Count, seconds=Window, type='burst_pattern']).

% Rule: unauthorized_device_activity
unauthorized_device_activity(Result, Evidence) :-
    get_fact(device_authorized, false),
    get_fact(attempt_type, 'PRIVILEGED_OP'),
    Result = 'HIGH_RISK_OBSERVATION',
    Evidence = json([message='Privileged operation attempted from unauthorized device']).
