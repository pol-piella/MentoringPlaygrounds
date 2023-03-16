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

// MARK: - Data Access Protocol
protocol DataAccess {
    func dataTask(with request: URLRequest, completion: @escaping (Result<Data, TransportError>) -> Void)
}

// MARK: - Transport
class Transport: DataAccess {
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
    
    let transport: DataAccess
    var urlRequestIsMadeTo: URL?
    
    init(withDataAccessor dataAccess: DataAccess) {
        self.transport = dataAccess
    }
    
    // if you mark a block with the autoclosure keyword it wraps the value you pass in, in a closure.
    // you can only use it with closres that take no arguments but  return something
    // e.g. ()  -> String etc.
    
    func fetchData(calendar: @autoclosure () -> Date=Date.init(), completion: @escaping () -> Void) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "httpbin.org"
        components.path = "/json"
        components.queryItems = [
            URLQueryItem(name: "date", value: calendar().ISO8601Format())
        ]
        let request = URLRequest(url: components.url!)
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
     - Test that the `URLRequest` is built with correct URL <tick>
     - Test that if `URLComponents` fails to build a URL, a custom error is returned
     - Test that the `date` passed as a query param is correct
     - Test that when the network request fails, a `ServiceError` is returned..
     - Test that when network request succeeds, correct decoded model is returned
     - Test that if decoding the data fails, an specific error is returned
     */
    
    func testGivenWeFetchData_RequestFormedCorrectly() {
        // GIVEN
        let expectedDate = Date()
        let expectedResult = URL(string: "https://httpbin.org/json?date=\(expectedDate.ISO8601Format())")
        // TODO: Mocks, doubles, fakes, spies!!??
        
        class MockDataAccess: DataAccess {
            
            var capturedRequest: URLRequest? = nil
            
            func dataTask(with request: URLRequest, completion: @escaping (Result<Data, TransportError>) -> Void) {
                self.capturedRequest = request
            }
        }
        
        let mockDataAccess: MockDataAccess = MockDataAccess()
        let service = Service(withDataAccessor: mockDataAccess)
        
        // WHEN
        service.fetchData(calendar: expectedDate) {}
        // THEN
        XCTAssertEqual(expectedResult, mockDataAccess.capturedRequest?.url)
        
    }
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

