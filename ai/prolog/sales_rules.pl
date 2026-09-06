% Sales Policy Logic

% Rule: sales_drop_alert
% Matches if revenue change is less than -20% and window is sufficient.
sales_drop_alert(Result, Evidence) :-
    get_fact(revenue_change, Change),
    get_fact(window_days, Window),
    Change < -0.20,
    Window >= 7,
    Result = 'SALES_DROP_ALERT',
    Evidence = json([change=Change, window=Window]).

% Rule: low_margin_alert
low_margin_alert(Result, Evidence) :-
    get_fact(margin, M),
    M < 0.10,
    Result = 'LOW_MARGIN_ALERT',
    Evidence = json([margin=M, threshold=0.10]).
