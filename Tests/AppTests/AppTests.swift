import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
import XCTest

@testable import App

final class AppTests: XCTestCase, @unchecked Sendable {
    struct TestArguments: AppArguments {
        let hostname = "127.0.0.1"
        let port = 0
        let logLevel: Logger.Level? = .trace
    }

	struct CreateRequest: Encodable {
		let title: String
		let order: Int?
	}

	func create(title: String, order: Int? = nil, client: some TestClientProtocol) async throws -> Todo {
		let request = CreateRequest(title: title, order: order)
		let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
		return try await client.execute(uri: "/todos", method: .post, body: buffer) { response in
			XCTAssertEqual(response.status, .created)
			return try JSONDecoder().decode(Todo.self, from: response.body)
		}
	}

	func get(id: UUID, client: some TestClientProtocol) async throws -> Todo? {
		try await client.execute(uri: "/todos/\(id)", method: .get) { response in
			// either the get request returned an 200 status or it didn't return a Todo
			if response.body.readableBytes > 0 {
				return try JSONDecoder().decode(Todo.self, from: response.body)
			} else {
				return nil
			}
		}
	}

	func list(client: some TestClientProtocol) async throws -> [Todo] {
		try await client.execute(uri: "/todos", method: .get) { response in
			XCTAssertEqual(response.status, .ok)
			return try JSONDecoder().decode([Todo].self, from: response.body)
		}
	}

	struct UpdateRequest: Encodable {
		let title: String?
		let order: Int?
		let completed: Bool?
	}

	func patch(id: UUID, title: String? = nil, order: Int? = nil, completed: Bool? = nil, client: some TestClientProtocol) async throws -> Todo? {
		let request = UpdateRequest(title: title, order: order, completed: completed)
		let buffer = try JSONEncoder().encodeAsByteBuffer(request, allocator: ByteBufferAllocator())
		return try await client.execute(uri: "/todos/\(id)", method: .patch, body: buffer) { response in
			XCTAssertEqual(response.status, .ok)
			if response.body.readableBytes > 0 {
				return try JSONDecoder().decode(Todo.self, from: response.body)
			} else {
				return nil
			}
		}
	}

	func delete(id: UUID, client: some TestClientProtocol) async throws -> HTTPResponse.Status {
		try await client.execute(uri: "/todos/\(id)", method: .delete) { response in
			return response.status
		}
	}

	func deleteAll(client: some TestClientProtocol) async throws {
		try await client.execute(uri: "/todos", method: .delete) { _ in }
	}

    func testCreate() async throws {
		let app = try await buildApplication(TestArguments())
        try await app.test(.router) { client in
			let todo = try await self.create(title: "My first todo", client: client)
			XCTAssertEqual(todo.title, "My first todo")
        }
    }

	func testPatch() async throws {
		let app = try await buildApplication(TestArguments())
		try await app.test(.router) { client in
			// create todo
			let todo = try await self.create(title: "Deliver parcels to James", client: client)
			// rename it
			_ = try await self.patch(id: todo.id, title: "Deliver parcels to Claire", client: client)
			let editedTodo = try await self.get(id: todo.id, client: client)
			XCTAssertEqual(editedTodo?.title, "Deliver parcels to Claire")
			// set it to completed
			_ = try await self.patch(id: todo.id, completed: true, client: client)
			let editedTodo2 = try await self.get(id: todo.id, client: client)
			XCTAssertEqual(editedTodo2?.isCompleted, true)
			// revert it
			_ = try await self.patch(id: todo.id, title: "Deliver parcels to James", completed: false, client: client)
			let editedTodo3 = try await self.get(id: todo.id, client: client)
			XCTAssertEqual(editedTodo3?.title, "Deliver parcels to James")
			XCTAssertEqual(editedTodo3?.isCompleted, false)
		}
	}

	func testAPI() async throws {
		let app = try await buildApplication(TestArguments())
		try await app.test(.router) { client in
			// create two todos
			let todo1 = try await self.create(title: "Wash my hair", client: client)
			let todo2 = try await self.create(title: "Brush my teeth", client: client)
			// get first todo
			let getTodo = try await self.get(id: todo1.id, client: client)
			XCTAssertEqual(getTodo, todo1)
			// patch second todo
			let optionalPatchedTodo = try await self.patch(id: todo2.id, completed: true, client: client)
			let patchedTodo = try XCTUnwrap(optionalPatchedTodo)
			XCTAssertEqual(patchedTodo.isCompleted, true)
			XCTAssertEqual(patchedTodo.title, todo2.title)
			// get all todos and check first todo and patched second todo are in the list
			let todos = try await self.list(client: client)
			XCTAssertNotNil(todos.firstIndex(of: todo1))
			XCTAssertNotNil(todos.firstIndex(of: patchedTodo))
			// delete a todo and verify it has been deleted
			let status = try await self.delete(id: todo1.id, client: client)
			XCTAssertEqual(status, .ok)
			let deletedTodo = try await self.get(id: todo1.id, client: client)
			XCTAssertNil(deletedTodo)
			// delete all todos and verify there are none left
			try await self.deleteAll(client: client)
			let todos2 = try await self.list(client: client)
			XCTAssertEqual(todos2.count, 0)
		}
	}

	func testDeletingTodoTwiceReturnsBadRequest() async throws {
		let app = try await buildApplication(TestArguments())
		try await app.test(.router) { client in
			// create a todo
			let todo = try await self.create(title: "This will be deleted", client: client)
			// delete todo
			let status = try await self.delete(id: todo.id, client: client)
			XCTAssertEqual(status, .ok)
			// delete again
			let status2 = try await self.delete(id: todo.id, client: client)
			XCTAssertEqual(status2, .badRequest)
		}
	}

	func testGettingTodoWithInvalidUUIDReturnsBadRequest() async throws {
		let app = try await buildApplication(TestArguments())
		try await app.test(.router) { client in
			_ = try await self.create(title: "This is just a dummy todo", client: client)
			let status = try await self.delete(id: UUID(), client: client)
			XCTAssertEqual(status, .badRequest)
		}
	}

	func test30ConcurrentlyCreatedTodosAreAllCreated() async throws {
		let repeatCount = 30
		let app = try await buildApplication(TestArguments())
		try await app.test(.router) { client in
			let todos = try await withThrowingTaskGroup(of: Todo.self, returning: [Todo].self) { group in
				for i in 0..<repeatCount {
					group.addTask { try await self.create(title: "\(i)", client: client) }
				}

				var todos: [Todo] = []
				for try await result in group {
					todos.append(result)
				}
				return todos
			}
			XCTAssertEqual(todos.count, repeatCount)

			var numbers: Set<Int> = Set(0..<repeatCount)
			for todo in todos {
				guard let number = Int(todo.title) else { continue }
				numbers.remove(number)
			}
			XCTAssertEqual(numbers.isEmpty, true)
		}
	}

	func testUpdatingNonExistentTodoReturnsBadRequest() async throws {
		let app = try await buildApplication(TestArguments())
		try await app.test(.router) { client in
			let status = try await self.patch(id: UUID(), client: client)
			XCTAssertEqual(status, .badRequest)
		}
	}
}
