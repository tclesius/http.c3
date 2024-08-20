import requests

url = "http://127.0.0.1:8000/users/"
data = {
    "name": "John Doe",
    "age": 30
}

response = requests.post(url, data=data)

print(response.status_code)
print(response.json())


payload = {'key1': 'value1', 'key2': ['value2', 'value3']}

r = requests.get('https://httpbin.org/get?test=test', params=payload)
print(r.url)