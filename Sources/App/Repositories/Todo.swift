// Created by Ahmet Karalar for Todos in 2024
// Using Swift 6.0

import Foundation
import Hummingbird

struct Todo {
	// Todo ID
	var id: UUID
	// Title
	var title: String
	// Order number
	var order: Int?
	// URL to get this todo
	var url: String
	// Is todo completed?
	var isCompleted: Bool
}

extension Todo: ResponseEncodable, Decodable, Equatable { }
