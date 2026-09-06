% JONKAI Core Prolog Rule Engine
% This file defines the core infrastructure for evaluating business rules.

:- dynamic signal_fact/2.
:- dynamic business_rule/4. % business_rule(Code, Version, Priority, Predicate)

% Clear dynamic facts for a clean session
clear_context :-
    retractall(signal_fact(_, _)).

% Assert a fact from Python
assert_signal(Key, Value) :-
    assertz(signal_fact(Key, Value)).

% Helper to get a signal fact
get_fact(Key, Value) :-
    signal_fact(Key, Value).

% Execute a specific rule
% RuleCode: The machine name of the rule (e.g., 'LOW_STOCK_REORDER')
% Result: The output atom (e.g., 'RESTOCK_REQUIRED')
% Evidence: A list or term containing supporting data
run_rule(RuleCode, Result, Evidence) :-
    Goal =.. [RuleCode, Result, Evidence],
    call(Goal).

% Default fallback for unknown rules
run_rule(_, 'SKIPPED', 'Rule predicate not found').
