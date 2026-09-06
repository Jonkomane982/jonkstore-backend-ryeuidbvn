% Inventory Rules

% Rule: low_stock_reorder
% Matches if quantity is less than or equal to reorder level and product is active.
low_stock_reorder(Result, Evidence) :-
    get_fact(quantity, Q),
    get_fact(reorder_level, RL),
    get_fact(product_active, true),
    Q =< RL,
    Result = 'RESTOCK_REQUIRED',
    Evidence = json([current_stock=Q, threshold=RL]).

% Rule: negative_stock_alert
negative_stock_alert(Result, Evidence) :-
    get_fact(quantity, Q),
    Q < 0,
    Result = 'CRITICAL_ERROR',
    Evidence = json([quantity=Q, message='Inventory cannot be negative']).
