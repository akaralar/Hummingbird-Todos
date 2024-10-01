// Created by Ahmet Karalar for Todos in 2024
// Using Swift 6.0

import Foundation
import Hummingbird

struct TodoController<Repository: TodoRepository> {
	let repository: Repository

	var endpoints: RouteCollection<AppRequestContext> {
		RouteCollection(context: AppRequestContext.self)
			.get(":id", use: get)
			.post(use: create)
	}

	@Sendable
	func get(request: Request, context: some RequestContext) async throws -> Todo? {
		let id = try context.parameters.require("id", as: UUID.self)
		return try await self.repository.get(id: id)
	}

	struct CreateRequest: Decodable {
		let title: String
		let order: Int?
	}

	@Sendable
	func create(request: Request, context: some RequestContext) async throws -> EditedResponse<Todo> {
		let request = try await request.decode(as: CreateRequest.self, context: context)
		let todo = try await self.repository.create(title: request.title, order: request.order, urlPrefix: "http://localhost:8080/todos/")
		return EditedResponse(status: .created, response: todo)
	}
}
