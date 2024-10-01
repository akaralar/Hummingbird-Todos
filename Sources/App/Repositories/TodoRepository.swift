// Created by Ahmet Karalar for Todos in 2024
// Using Swift 6.0

import Foundation


protocol TodoRepository: Sendable {
	func create(title: String, order: Int?, urlPrefix: String) async throws -> Todo
	func get(id: UUID) async throws -> Todo?
	func list() async throws -> [Todo]
	func update(id: UUID, title: String?, order: Int?, completed: Bool?) async throws -> Todo?
	func delete(id: UUID) async throws -> Bool
	func deleteAll() async throws
}
