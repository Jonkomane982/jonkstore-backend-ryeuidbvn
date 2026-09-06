% Pricing Rules

% Rule: price_deviation_alert
% Matches if product price deviates significantly from average or policy.
price_deviation_alert(Result, Evidence) :-
    get_fact(price, P),
    get_fact(avg_market_price, Avg),
    Diff is abs(P - Avg) / Avg,
    Diff > 0.30,
    Result = 'REVIEW_PRICE',
    Evidence = json([price=P, market_avg=Avg, deviation_pct=Diff]).

% Rule: margin_risk_alert
margin_risk_alert(Result, Evidence) :-
    get_fact(selling_price, S),
    get_fact(buying_price, B),
    S > 0,
    Margin is (S - B) / S,
    Margin < 0.05,
    Result = 'MARGIN_RISK',
    Evidence = json([margin=Margin, threshold=0.05]).
