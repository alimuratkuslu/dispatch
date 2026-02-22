import Foundation

let config = URLSessionConfiguration.ephemeral
let session = URLSession(configuration: config)

let url = URL(string: "https://github.com/login/device/code")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
let body = "client_id=Ov23livX5JNXFnnsO4pk&scope=repo%20read:user%20notifications"
request.httpBody = body.data(using: .utf8)

let semaphore = DispatchSemaphore(value: 0)
let task = session.dataTask(with: request) { data, response, error in
    if let data = data, let str = String(data: data, encoding: .utf8) {
        if let http = response as? HTTPURLResponse {
            print("Status: \(http.statusCode)")
        }
        print(str)
    }
    semaphore.signal()
}
task.resume()
semaphore.wait()
