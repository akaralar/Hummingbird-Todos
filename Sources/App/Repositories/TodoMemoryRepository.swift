// Created by Ahmet Karalar for Todos in 2024
// Using Swift 6.0

import Foundation


actor TodoMemoryRepository: TodoRepository, Sendable {
	var todos: [UUID: Todo]

	init() {
		self.todos = [:]
	}

	func create(title: String, order: Int?, urlPrefix: String) async throws -> Todo {
		let id = UUID()
		let url = urlPrefix + id.uuidString
		let todo = Todo(id: id, title: title, order: order, url: url, isCompleted: false)
		self.todos[id] = todo
		return todo
	}

	func get(id: UUID) async throws -> Todo? {
		self.todos[id]
	}

	func list() async throws -> [Todo] {
		Array(self.todos.values)
	}

	func update(id: UUID, title: String?, order: Int?, completed: Bool?) async throws -> Todo? {
		if var todo = self.todos[id] {
			if let title = title {
				todo.title = title
			}
			if let order = order {
				todo.order = order
			}
			if let completed = completed {
				todo.isCompleted = completed
			}
			self.todos[id] = todo
			return todo
		}
		return nil
	}

	func delete(id: UUID) async throws -> Bool {
		if self.todos[id] != nil {
			self.todos[id] = nil
			return true
		}
		return false
	}

	func deleteAll() async throws {
		self.todos.removeAll()
	}
}
