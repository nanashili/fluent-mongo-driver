import FluentKit
import MongoKitten
import MongoCore

extension _MongoDB {
    func update(
        query: DatabaseQuery,
        onRow: @escaping (DatabaseRow) -> ()
    ) -> EventLoopFuture<Void> {
        do {
            let filter = try query.makeMongoDBFilter()
            let update = try query.makeValueDocuments()
            
            let updates = update.map { document -> UpdateCommand.UpdateRequest in
                var update = UpdateCommand.UpdateRequest(
                    where: filter,
                    to: [
                        "$set": document
                    ]
                )
                
                update.multi = true
                
                return update
            }
            
            let command = UpdateCommand(updates: updates, inCollection: query.schema)
            return cluster.next(for: .init(writable: true)).flatMap { connection in
                return connection.executeCodable(
                    command,
                    namespace: MongoNamespace(to: "$cmd", inDatabase: self.raw.name),
                    sessionId: nil
                )
            }.decode(UpdateReply.self).flatMapThrowing { reply in
                let reply = _MongoDBAggregateResponse(value: reply.updatedCount, decoder: BSONDecoder())
                
                onRow(reply)
            }
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
    }
}
