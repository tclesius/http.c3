import requests

response = requests.get('http://httpbin.org/redirect/3')
print(response.history)