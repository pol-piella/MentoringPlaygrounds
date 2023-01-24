import UIKit
import XCTest

public enum TransportError: Error {
    case httpError(statusCode: Int)
    case noNetwork
    case noData
    case invalidResponseType
    case other(Error)
}

struct Model: Decodable {
    let slideshow: [Slide]
    let author: String
    let title: String
}

struct Slide: Decodable {
    let title: String
}

// MARK: - Transport
class Transport {
    func dataTask(with request: URLRequest, completion: @escaping (Result<Data, TransportError>) -> Void) {
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error {
                if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                    return completion(.failure(.noNetwork))
                }
                
                completion(.failure(.other(error)))
            } else {
                guard let response = response as? HTTPURLResponse else {
                    return completion(.failure(.invalidResponseType))
                }
                
                switch response.statusCode {
                case 200...299:
                    if let data {
                        completion(.success(data))
                    } else {
                        completion(.failure(.noData))
                    }
                default:
                    return completion(.failure(.httpError(statusCode: response.statusCode)))
                }
            }
        }
        .resume()
    }
}

enum ServiceError: Error {}

// MARK: - Service
class Service {
    func fetchData(_ completion: @escaping () -> Void) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "httpbin.org"
        components.path = "/json"
        components.queryItems = [
            URLQueryItem(name: "date", value: Date().ISO8601Format())
        ]
        let request = URLRequest(url: components.url!)
        let transport = Transport()
        transport.dataTask(with: request) { result in
            // Map or return an error here...
            completion()
        }
    }
}

// MARK: - Unit Tests
class ServiceTests: XCTestCase {
    /*
     Refactor so that we can:
     - Test that the `URLRequest` is built with correct URL
     - Test that if `URLComponents` fails to build a URL, a custom error is returned
     - Test that the `date` passed as a query param is correct
     - Test that when the network request fails, a `ServiceError` is returned..
     - Test that when network request succeeds, correct decoded model is returned
     - Test that if decoding the data fails, an specific error is returned
     */
}

// MARK: - Setup Unit Testing from a playground
class TestObserver: NSObject, XCTestObservation {
    func testCase(_ testCase: XCTestCase,
                  didFailWithDescription description: String,
                  inFile filePath: String?,
                  atLine lineNumber: Int) {
        assertionFailure(description, line: UInt(lineNumber))
    }
}

let testObserver = TestObserver()
XCTestObservationCenter.shared.addTestObserver(testObserver)
ServiceTests.defaultTestSuite.run()
