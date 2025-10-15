import json
import uuid
import requests

def test_items_crud_flow(api_urls):
    # build URLs
    items_url = api_urls["items"]
    item_id = f"p-{uuid.uuid4().hex[:8]}"
    one_item_url = f"{items_url}/{item_id}"

    # CREATE
    r = requests.post(items_url, json={"id": item_id, "name": "Test Thing", "price": 12.5})
    assert r.status_code in (200, 201), r.text

    # GET by id
    r = requests.get(one_item_url)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["item"]["id"] == item_id
    assert "price" in body["item"]

    # LIST
    r = requests.get(items_url)
    assert r.status_code == 200
    items = r.json().get("items", [])
    assert any(i.get("id") == item_id for i in items)

    # UPDATE (PUT)
    r = requests.put(one_item_url, json={"price": 14.0, "name": "Test Thing+"})
    assert r.status_code == 200, r.text

    # GET again
    r = requests.get(one_item_url)
    assert r.status_code == 200
    assert r.json()["item"]["name"].startswith("Test Thing")

    # DELETE
    r = requests.delete(one_item_url)
    assert r.status_code in (200, 204), r.text

    # Should be gone
    r = requests.get(one_item_url)
    assert r.status_code == 404
