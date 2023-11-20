import SwiftUI
import Pulse

struct DebugAnalyticsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)],
        predicate: makePredicate(searchText: "")
    ) var messages: FetchedResults<LoggerMessageEntity>

    @State private var searchText = ""

    var body: some View {
        List(messages, id: \.objectID) { message in
            VStack(alignment: .leading) {
                HStack {
                    Text(timeFormatter.string(from: message.createdAt))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    ListDisclosureIndicator()
                }
                Text(message.text)
                    .lineLimit(2)
            }
            .background(NavigationLink("", destination: DebugAnalyticsDetailsView(message: message)).opacity(0))
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) {
            messages.nsPredicate = makePredicate(searchText: $0)
        }
        .navigationTitle("Analytics")
        .listStyle(.plain)
    }
}

private func makePredicate(searchText: String) -> NSPredicate {
    let basePredicate = NSPredicate(format: "label == %@ && session == %@", "analytics", LoggerStore.shared.session.id as NSUUID)
    let searchTerms = searchText
        .trimmingCharacters(in: .whitespaces)
        .components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }
    guard !searchTerms.isEmpty else { return basePredicate }
    let searchPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: searchTerms.map {
        NSPredicate(format: "text CONTAINS[cd] %@", $0)
    })
    return NSCompoundPredicate(andPredicateWithSubpredicates: [basePredicate, searchPredicates])
}

private struct DebugAnalyticsDetailsView: View {
    let message: LoggerMessageEntity

    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                makeRow(title: "Event", value: message.text)
                makeRow(title: "Date", value: message.createdAt.description)
            }
            let metadata = self.metadata
            if !metadata.isEmpty {
                Section("Metadata") {
                    ForEach(metadata, id: \.0, content: makeRow)
                }
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metadata: [(String, String)] {
        Array(message.metadata).sorted {
            $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }.filter {
            guard !searchText.isEmpty else { return true }
            return $0.key.localizedCaseInsensitiveContains(searchText) ||
            $0.value.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func makeRow(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(higlighted(title, searchText: searchText))
                .fontWeight(.medium)
            Text(higlighted(value, searchText: searchText))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ListDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(Color(UIColor.separator))
            .lineLimit(1)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.trailing, -12)
    }
}

private func higlighted(_ string: String, searchText: String) -> AttributedString {
    var output = AttributedString(string)
    if !searchText.isEmpty, let range = output.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) {
        output[range].backgroundColor = .yellow.opacity(0.33)
    }
    return output
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
}()
