import SwiftUI

struct QuickAddButton: View {
    let option: QuickAddOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.title2)
                
                Text(option.label)
                    .font(.caption)
                
                Text("\(option.amount)ml")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct QuickAddButtonRow: View {
    let onAdd: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(QuickAddOption.allCases) { option in
                QuickAddButton(option: option) {
                    onAdd(option.amount)
                }
            }
        }
    }
}

#Preview {
    QuickAddButtonRow { amount in
        print("Add \(amount)ml")
    }
    .padding()
}
