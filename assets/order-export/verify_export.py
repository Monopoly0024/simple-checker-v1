"""Exercise independent expectations; the deliberately buggy export must fail completeness."""
import argparse
import copy
import json
from orders import export_orders, list_orders


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', choices=['E1', 'E2', 'E3', 'E4'])
    args = parser.parse_args()
    rows = [{'id': n, 'status': 'paid', 'total': n * 10, 'internal': 'not exported'}
            for n in range(1, 36)]
    rows += [{'id': 1001, 'status': 'unpaid', 'total': 10}]
    before = copy.deepcopy(rows)
    actual = export_orders(rows, 'paid')
    checks = [
        {'id': 'E1', 'passed': [r['id'] for r in actual] == list(range(1, 36)),
         'expected': '35 paid orders, IDs 1..35',
         'observed': f'{len(actual)} orders, IDs {[r["id"] for r in actual]}'},
        {'id': 'E2', 'passed': ([r['id'] for r in list_orders(rows, 'paid')] == list(range(1, 21))
                              and [r['id'] for r in list_orders(rows, 'paid', page=2)] == list(range(21, 36))),
         'expected': 'First page IDs 1..20; second page IDs 21..35; only paid rows',
         'observed': f'First page {len(list_orders(rows, "paid"))}; second page {len(list_orders(rows, "paid", page=2))}'},
        {'id': 'E3', 'passed': all(set(r) == {'id', 'status', 'total'} and r['total'] == r['id'] * 10 for r in actual),
         'expected': 'Exactly id,status,total with values matching source for returned rows',
         'observed': f'{len(actual)} returned rows have fields id,status,total and matching total'},
        {'id': 'E4', 'passed': rows == before and all(out is not source for out in actual for source in rows),
         'expected': 'Input deeply unchanged; output dictionaries distinct from source',
         'observed': f'Input unchanged={rows == before}; output dictionaries are new objects'},
    ]
    if args.check:
        checks = [check for check in checks if check['id'] == args.check]
    print(json.dumps({'checks': checks, 'note': 'No file download or actual web service exercised.'}, ensure_ascii=False))
    return 1 if any(not check['passed'] for check in checks) else 0


if __name__ == '__main__':
    raise SystemExit(main())
