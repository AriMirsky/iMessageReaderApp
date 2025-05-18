import SwiftUI

struct ReadabilityView: View {
    @EnvironmentObject var vm: ReadabilityViewModel
    @EnvironmentObject var contacts: ContactsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Incoming Section
                Text("Popular 10 Incoming Scores")
                    .font(.title3).bold()

                // Header Row
                HStack(spacing: 16) {
                    Text("Name")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Data Rows
                ForEach(vm.popular10Incoming) { e in
                    HStack(spacing: 16) {
                        Text(contacts.displayName(for: e.person))
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", e.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.words)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.sentences)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(e.syllables)")
                            .frame(width: 80, alignment: .trailing)
                    }
                }

                Divider()

                // Outgoing Section
                Text("Popular 10 Outgoing Scores")
                    .font(.title3).bold()

                // Header Row
                HStack(spacing: 16) {
                    Text("Name")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Data Rows
                ForEach(vm.popular10Outgoing) { e in
                    HStack(spacing: 16) {
                        Text(contacts.displayName(for: e.person))
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", e.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.words)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.sentences)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(e.syllables)")
                            .frame(width: 80, alignment: .trailing)
                    }
                }
                // Incoming Section
                Text("Top 5 Incoming Scores")
                    .font(.title3).bold()

                // Header Row
                HStack(spacing: 16) {
                    Text("Name")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Data Rows
                ForEach(vm.top5Incoming) { e in
                    HStack(spacing: 16) {
                        Text(contacts.displayName(for: e.person))
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", e.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.words)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.sentences)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(e.syllables)")
                            .frame(width: 80, alignment: .trailing)
                    }
                }

                Divider()

                // Outgoing Section
                Text("Top 5 Outgoing Scores")
                    .font(.title3).bold()

                // Header Row
                HStack(spacing: 16) {
                    Text("Name")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Data Rows
                ForEach(vm.top5Outgoing) { e in
                    HStack(spacing: 16) {
                        Text(contacts.displayName(for: e.person))
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", e.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.words)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.sentences)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(e.syllables)")
                            .frame(width: 80, alignment: .trailing)
                    }
                }
                
                // Incoming Section
                Text("Bottom 5 Incoming Scores")
                    .font(.title3).bold()

                // Header Row
                HStack(spacing: 16) {
                    Text("Name")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Data Rows
                ForEach(vm.bottom5Incoming) { e in
                    HStack(spacing: 16) {
                        Text(contacts.displayName(for: e.person))
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", e.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.words)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.sentences)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(e.syllables)")
                            .frame(width: 80, alignment: .trailing)
                    }
                }

                Divider()

                // Outgoing Section
                Text("Bottom 5 Outgoing Scores")
                    .font(.title3).bold()

                // Header Row
                HStack(spacing: 16) {
                    Text("Name")
                        .frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Grade Level")
                        .frame(width: 50, alignment: .trailing)
                    Text("Words")
                        .frame(width: 50, alignment: .trailing)
                    Text("Sentences")
                        .frame(width: 80, alignment: .trailing)
                    Text("Syllables")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Data Rows
                ForEach(vm.bottom5Outgoing) { e in
                    HStack(spacing: 16) {
                        Text(contacts.displayName(for: e.person))
                            .frame(width: 150, alignment: .leading)
                        Spacer()
                        Text(String(format: "%.1f", e.score))
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.words)")
                            .frame(width: 50, alignment: .trailing)
                        Text("\(e.sentences)")
                            .frame(width: 80, alignment: .trailing)
                        Text("\(e.syllables)")
                            .frame(width: 80, alignment: .trailing)
                    }
                }

            }
            .padding()
        }
        .navigationTitle("Readability Scores")
    }
}

#if DEBUG
struct ReadabilityView_Previews: PreviewProvider {
    static var previews: some View {
        ReadabilityView()
            .environmentObject(ReadabilityViewModel())
            .environmentObject(ContactsViewModel())
    }
}
#endif
