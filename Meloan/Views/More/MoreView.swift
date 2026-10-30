import SwiftUI

// swiftlint:disable type_body_length
struct MoreView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @AppStorage(wrappedValue: true, "MarkSelfPaid", store: defaults) var markSelfPaid: Bool
    @AppStorage(wrappedValue: 0.0, "TaxRate", store: defaults) var taxRate: Double
    @AppStorage(wrappedValue: "", "TaxRateCountry", store: defaults) var taxRateCountry: String
    @AppStorage(wrappedValue: "", "TaxRateType", store: defaults) var taxRateType: String
    @AppStorage(wrappedValue: false, "AddTenPercent", store: defaults) var addTenPercent: Bool
    @AppStorage(wrappedValue: false, "TaxAboveServiceCharge", store: defaults) var taxAboveServiceCharge: Bool
    @AppStorage(wrappedValue: "", "CurrencySymbol", store: defaults) var currencySymbol: String
    @AppStorage(wrappedValue: decimalPlacesSetting(), "DecimalPlaces", store: defaults) var decimalPlaces: Int
    @AppStorage(wrappedValue: false, "UseCurrencyGlyph", store: defaults) var useCurrencyGlyph: Bool
    @AppStorage(wrappedValue: 0, "ShareRounding", store: defaults) var shareRounding: Int
    @State var currencyPreview: String = format(1234.567)

    var body: some View {
        NavigationStack(path: $navigationManager.moreTabPath) {
            List {
                Section {
                    NavigationLink(value: ViewPath.moreData) {
                        Text("More.Data")
                    }
                } header: {
                    Text("More.General")
                }
                Section {
                    Toggle("More.Receipts.MarkSelfPaid", isOn: $markSelfPaid)
                    Menu {
                        Button {
                            taxRate = 0.0
                            taxRateCountry = ""
                            taxRateType = ""
                        } label: {
                            HStack {
                                Text("TaxRate.Disable")
                                if taxRateCountry == "" {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        ForEach(Array(taxRates.keys).sorted(by: { countryName(for: $0) < countryName(for: $1) }),
                                id: \.self) { countryCode in
                            if let rate = taxRates[countryCode] {
                               if let states = rate.states {
                                   Menu(countryName(for: countryCode)) {
                                       ForEach(Array(states.keys)
                                        .sorted(by: { countryName(for: $0) < countryName(for: $1) }),
                                               id: \.self) { stateCode in
                                           if let state = states[stateCode] {
                                               taxRateButton(countryCode: "\(countryCode)-\(stateCode)",
                                                             rate: state)
                                           }
                                       }
                                   }
                                } else {
                                    taxRateButton(countryCode: countryCode, rate: rate)
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("More.Receipts.AutomaticTaxRate")
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Group {
                                if taxRateCountry == "" {
                                    Text("TaxRate.Disable")
                                } else {
                                    Text(countryName(for: taxRateCountry))
                                }
                            }
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .tint(.primary)
                    }
                    Toggle("More.Receipts.ServiceCharge", isOn: $addTenPercent)
                    if addTenPercent && taxRateCountry != "" {
                        Toggle("More.Receipts.TaxAboveServiceCharge", isOn: $taxAboveServiceCharge)
                    }
                } header: {
                    Text("More.Receipts")
                } footer: {
                    Text("More.Receipts.Footer")
                        .font(.subheadline)
                }
                Section {
                    Text(verbatim: currencyPreview)
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8.0)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    Menu {
                        Button {
                            currencySymbol = ""
                        } label: {
                            HStack {
                                Text("Currency.Hide")
                                if currencySymbol == "" {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        ForEach(currencies.sorted(), id: \.self) { currencyCode in
                            Button {
                                currencySymbol = currencyCode
                            } label: {
                                Text(NSLocalizedString("Currency.\(currencyCode)", comment: ""))
                                    .tag(currencyCode)
                                if currencySymbol == currencyCode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("More.Currency.Symbol")
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Group {
                                if currencySymbol == "" {
                                    Text("Currency.Hide")
                                } else {
                                    Text(NSLocalizedString("Currency.\(currencySymbol)", comment: ""))
                                }
                            }
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .tint(.primary)
                    }
                    if currencySymbol != "" && currencyHasSymbol(currencySymbol) {
                        Toggle("More.Currency.UseSymbol", isOn: $useCurrencyGlyph)
                    }
                    Picker("More.Currency.Decimals", selection: $decimalPlaces) {
                        Text("More.Currency.Decimals.Automatic").tag(automaticDecimalPlaces)
                        Text("More.Currency.Decimals.None").tag(0)
                        ForEach(1...3, id: \.self) { places in
                            Text(verbatim: String(places)).tag(places)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    Picker("More.Currency.Rounding", selection: $shareRounding) {
                        Text("More.Currency.Rounding.Off").tag(0)
                        ForEach(shareRoundingUnits, id: \.self) { unit in
                            Text(verbatim: String(unit)).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                } header: {
                    Text("More.Currency")
                } footer: {
                    Text("More.Currency.Rounding.Footer")
                        .font(.subheadline)
                }
                Section {
                    NavigationLink(value: ViewPath.moreTroubleshooting) {
                        Text("More.Troubleshooting")
                    }
                } header: {
                    Text("More.Advanced")
                }
                Section {
                    Link(destination: URL(string: "https://github.com/AtelierSuite/Dues")!) {
                        HStack {
                            Text(String(localized: "More.GitHub"))
                            Spacer()
                            Text("AtelierSuite/Dues")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink("More.Attributions", value: ViewPath.moreLicenses)
                }
            }
            .navigationTitle("ViewTitle.More")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .moreData: MoreManageDataView()
                case .moreTroubleshooting: MoreTroubleshootingView()
                case .moreLicenses: MoreLicensesView()
                default: Color.clear
                }
            }
        }
        .onChange(of: currencySymbol, { _, _ in
            currencySettingsDidChange()
        })
        .onChange(of: decimalPlaces, { _, _ in
            currencySettingsDidChange()
        })
        .onChange(of: useCurrencyGlyph, { _, _ in
            currencySettingsDidChange()
        })
        .onChange(of: shareRounding, { _, _ in
            DuesApp.reloadWidget()
        })
    }

    func currencySettingsDidChange() {
        // Menu selections are applied with animations disabled, so update the preview afterwards
        DispatchQueue.main.async {
            withAnimation(.snappy) {
                currencyPreview = format(1234.567)
            }
        }
        DuesApp.reloadWidget()
    }

    @ViewBuilder
    func taxRateButton(countryCode: String, rate: TaxRate) -> some View {
        Button {
            taxRateCountry = countryCode
            taxRate = rate.rate
            taxRateType = rate.type.rawValue
        } label: {
            HStack {
                Text(verbatim: countryName(for: countryCode))
                if countryCode == taxRateCountry {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
// swiftlint:enable type_body_length
