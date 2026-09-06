% JONKAI Core Prolog Logic
:- dynamic signal_fact/2.

% Helper to retrieve signal facts
get_signal(Key, Value) :-
    signal_fact(Key, Value).

% Standard evaluation wrapper for database-driven rules
evaluate_rule(PredicateName, Result, Evidence) :-
    Goal =.. [PredicateName, Result, Evidence],
    call(Goal).
