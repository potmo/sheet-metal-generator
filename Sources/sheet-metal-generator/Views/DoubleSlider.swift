import SwiftUI

struct DoubleSlider: View {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    let label: String
    @Binding var value: Double

    let range: ClosedRange<Double>
    var body: some View {
        Slider(value: $value, in: range) {
            HStack(spacing: 1.0) {
                Spacer()
                Text("\(label)").foregroundColor(Color.gray)
                TextField("", value: $value, formatter: Self.formatter)
                    .fixedSize(horizontal: true, vertical: true)
                    .textFieldStyle(.roundedBorder)
            }.frame(width: 150)
        }
    }
}
