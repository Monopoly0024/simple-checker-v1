def list_orders(rows, status, page=1, page_size=20):
    matched = [row for row in rows if row['status'] == status]
    start = (page - 1) * page_size
    return matched[start:start + page_size]


def export_orders(rows, status):
    selected = list_orders(rows, status)
    return [{key: row[key] for key in ('id', 'status', 'total')} for row in selected]
