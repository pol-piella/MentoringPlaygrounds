import UIKit
import XCTest

public enum TransportError: Error, Equatable {
    public static func == (lhs: TransportError, rhs: TransportError) -> Bool {
        switch (lhs, rhs) {
        case (.httpError(let lhsStatusCode), .httpError(let rhsStatusCode)):
            return lhsStatusCode == rhsStatusCode
        case (.noNetwork, .noNetwork): return true
        case (.noData, .noData): return true
        case (.invalidResponseType, .invalidResponseType): return true
        case (.invalidUrl, .invalidUrl): return true
        case (.other(let lhsError), .other(let rhsError)):
            // This may not be best practice, what you may wish to do in real life is inspect the status codes (possibly on NSError - would need to check!)
            return lhsError.localizedDescription == rhsError.localizedDescription
        default: return false
        }
    }
    
    case httpError(statusCode: Int)
    case noNetwork
    case noData
    case invalidResponseType
    case invalidUrl
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
    
    func fetchData(calendar: @autoclosure () -> Date=Date.init(), completion: @escaping (Result<Data, TransportError>) -> Void) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "httpbin.org"
        components.path = "/json"
        components.queryItems = [
            URLQueryItem(name: "date", value: calendar().ISO8601Format())
        ]
        if let url = components.url {
            let request = URLRequest(url: url)
            transport.dataTask(with: request) { result in
                // Map or return an error here...
                switch result {
                case .success(let data):
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.failure(TransportError.invalidUrl))
        }
        
    }
}

// MARK: - Unit Tests
class ServiceTests: XCTestCase {
    /*
     Refactor so that we can:
     - Test that the `URLRequest` is built with correct URL <tick>
     - Test that if `URLComponents` fails to build a URL, a custom error is returned
     - Test that the `date` passed as a query param is correct <tick>
     - Test that when the network request fails, a `ServiceError` is returned..
     - Test that when network request succeeds, correct decoded model is returned
     - Test that if decoding the data fails, an specific error is returned
     */
    
    func testGivenWeFetchData_RequestFormedCorrectly() {
        // GIVEN
        let expectedDate = Date()
        let expectedResult = URL(string: "https://httpbin.org/json?date=\(expectedDate.ISO8601Format())")
        // TODO: Mocks, doubles, fakes, spies!!??
                
        let mockDataAccess: MockDataAccess = MockDataAccess()
        let service = Service(withDataAccessor: mockDataAccess)
        
        // WHEN
        service.fetchData(calendar: expectedDate) {_ in }
        // THEN
        XCTAssertEqual(expectedResult, mockDataAccess.capturedRequest?.url)
        
    }
    
    func testGivenInvalidURL_WhenBuiltByURLComponents_ThenAppropriateErrorIsReturned (){
        // Given
        let mockDataAccess: MockDataAccess = MockDataAccess()
        let service = Service(withDataAccessor: mockDataAccess)
        
        // When
        // TO DO: - this test is passing!!
        // We need to make a URL builder injectable so we can see a failure on the URL. 
       service.fetchData { result in
            switch result {
            case .success:
                XCTFail("Shouldn't have entered success block")
            case .failure(let error):
                // Then
                // We are mocking the async layer so we don't need an expectation
                // If you are not sure try printing!
                // INB Think about the code further down the line in complex systems - are you managing queues somewhere?
                // In which case you may need to use expectations
                XCTAssertEqual(TransportError.invalidUrl, error)
            }
        }
    }
}

// MARK: - DataAccess Object for Tests

class MockDataAccess: DataAccess {
    
    var capturedRequest: URLRequest? = nil
    
    func dataTask(with request: URLRequest, completion: @escaping (Result<Data, TransportError>) -> Void) {
        self.capturedRequest = request
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

