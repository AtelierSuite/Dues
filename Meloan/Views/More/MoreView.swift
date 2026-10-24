//
//  MoreView.swift
//  Meloan
//
//  Created by シン・ジャスティン on 2023/09/16.
//

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
    @AppStorage(wrappedValue: true, "ShowDecimals", store: defaults) var showDecimals: Bool

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
                    Toggle("More.Currency.Decimals", isOn: $showDecimals)
                } header: {
                    Text("More.Currency")
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
            DuesApp.reloadWidget()
        })
        .onChange(of: showDecimals, { _, _ in
            DuesApp.reloadWidget()
        })
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
