@testable import FlowDown
import Foundation
@testable import Storage
import Testing

@Suite(.serialized)
struct OnlineModelBackedE2ETests {
    private func withTemporaryCloudModel<T>(
        _ body: @escaping (ModelManager.ModelIdentifier) async throws -> T
    ) async throws -> T {
        try await FlowDownTestContext.shared.ensureBootstrappedEnvironment()
        let model = try OnlineE2ETestSupport.runtimeCloudModel()

        await MainActor.run {
            ModelManager.shared.insertCloudModel(model)
        }

        do {
            let result = try await body(model.id)
            await MainActor.run {
                ModelManager.shared.removeCloudModel(identifier: model.id)
            }
            return result
        } catch {
            await MainActor.run {
                ModelManager.shared.removeCloudModel(identifier: model.id)
            }
            throw error
        }
    }

    @MainActor
    private func makeConversation(
        title: String,
        modelID: ModelManager.ModelIdentifier,
        exchanges: [(Message.Role, String)]
    ) -> Conversation.ID {
        ConversationManager.shouldShowGuideMessage = false
        let conversation = ConversationManager.shared.createNewConversation {
            $0.update(\.title, to: title)
            $0.update(\.modelId, to: modelID)
            $0.update(\.shouldAutoRename, to: true)
            $0.update(\.icon, to: Data())
        }

        let session = ConversationSessionManager.shared.session(for: conversation.id)
        session.models.chat = modelID
        session.models.auxiliary = modelID

        for message in session.messages where message.role == .assistant {
            session.delete(messageIdentifier: message.objectId)
        }

        for (role, text) in exchanges {
            session.appendNewMessage(role: role) {
                $0.update(\.document, to: text)
            }
        }

        session.save()
        session.notifyMessagesDidChange()
        return conversation.id
    }

    @MainActor
    private func deleteConversationIfPresent(_ identifier: Conversation.ID?) {
        guard let identifier else { return }
        guard ConversationManager.shared.conversation(identifier: identifier) != nil else { return }
        ConversationManager.shared.deleteConversation(identifier: identifier)
    }

    @Test(.enabled(if: OnlineE2ETestSupport.isEnabled))
    @MainActor
    func `auto rename e2e updates title and icon with one metadata generation flow`() async throws {
        try await withTemporaryCloudModel { modelID in
            let originalTitle = "Pending auto rename \(UUID().uuidString.prefix(8))"
            let conversationID = makeConversation(
                title: originalTitle,
                modelID: modelID,
                exchanges: [
                    (.user, "Help me name this chat. We are planning a four day Kyoto trip focused on temples, vegetarian food, and a lean budget."),
                    (.assistant, "Plan saved: four days in Kyoto with temple visits, affordable vegetarian spots, neighborhood-based walking routes, and rainy day backups."),
                ],
            )

            defer {
                deleteConversationIfPresent(conversationID)
            }

            let session = ConversationSessionManager.shared.session(for: conversationID)
            #expect(session.shouldAutoRename)

            await session.updateTitleAndIcon()

            let updatedConversation = try #require(ConversationManager.shared.conversation(identifier: conversationID))

            #expect(!updatedConversation.shouldAutoRename)
            #expect(!updatedConversation.title.isEmpty)
            #expect(updatedConversation.title != originalTitle)
            #expect(updatedConversation.title.count <= 32)
            #expect(!updatedConversation.title.contains("<title>"))
            #expect(!updatedConversation.title.contains("**"))
            #expect(!updatedConversation.icon.isEmpty)
        }
    }
}
