//
//  DisclaimerView.swift
//  DemoDICOM
//
//  Created by Igor Tarantino on 23/05/2026.
//

import SwiftUI

struct DisclaimerView: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        
        ScrollView {
        VStack(alignment: .leading, spacing: 25) {
            
            HStack {
                Text("Disclaimer")
                    .font(.title)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                Image("atrialogo1")
                    .frame(width: 250, height: 150)
                Spacer()
            }
            
            HStack {
                Text("Disclaimer")
                    .font(.title)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 18) {

                Text("ATRIA is a **clinical communication and visualisation tool** designed exclusively for use by licensed medical professionals in the context of multidisciplinary pre-operative team meetings. It is not a diagnostic device.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Not approved for primary diagnosis")
                        .fontWeight(.semibold)
                    Text("ATRIA has not been cleared or approved by the U.S. Food and Drug Administration (FDA), the European Medicines Agency (EMA), or any other regulatory authority as a medical device. The DICOM images, measurements, and data displayed within this application must not be used as the sole or primary basis for any clinical diagnosis, treatment planning, or patient management decision.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Professional responsibility")
                        .fontWeight(.semibold)
                    Text("All clinical decisions remain the sole responsibility of the licensed medical professional using this application. By using ATRIA, you confirm that you are a qualified healthcare provider acting within your scope of practice and that you will apply independent clinical judgement when interpreting any information presented herein.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Data accuracy")
                        .fontWeight(.semibold)
                    Text("The accuracy and completeness of the medical data displayed depends entirely on the integrity of the source files imported by the user. ATRIA does not validate, alter, or verify the clinical accuracy of imported DICOM studies or documents. The development team accepts no liability for errors arising from corrupted, incomplete, or mislabelled source data.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("No patient data warranty")
                        .fontWeight(.semibold)
                    Text("This application does not constitute a certified electronic health record (EHR) or picture archiving and communication system (PACS). It must not be used as the authoritative repository for patient data. Ensure that all patient information is managed in compliance with applicable data protection regulations (HIPAA, GDPR, or equivalent).")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Connectivity and synchronisation")
                        .fontWeight(.semibold)
                    Text("Features relying on SharePlay or network connectivity are subject to interruption. The development team assumes no responsibility for loss of synchronisation, data transmission failures, or decisions made during degraded connectivity.")
                        .foregroundStyle(.secondary)
                }

                Text("By proceeding, you acknowledge that you have read and understood this disclaimer and accept full responsibility for any clinical or operational use of this application.")
                    .fontWeight(.semibold)

            }
            
//            HStack {
//                Text("Citations")
//                    .font(.title)
//                
//                Spacer()
//            }
//            
//            Text("Insert here all the citations")
            
            Button {
                openURL(URL(string: "https://atria-team.github.io/privacy")!)
            } label: {
                Rectangle()
                  .foregroundColor(.clear)
                  .frame(width: 400, height: 40)
                  .background(
                    LinearGradient(
                      stops: [
                        Gradient.Stop(color: Color(red: 0.32, green: 0.32, blue: 0.32).opacity(0.5), location: 0.00),
                        Gradient.Stop(color: Color(red: 0.45, green: 0.45, blue: 0.45).opacity(0.35), location: 1.00),
                      ],
                      startPoint: UnitPoint(x: 0.5, y: 1),
                      endPoint: UnitPoint(x: 0.5, y: 0)
                    )
                  )
                  .cornerRadius(20)
                  .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                  .overlay(
                    ZStack {
                        Text("More info about ATRIA - Heart Team Meetings")
                    }
                  )
                  .glassBackgroundEffect()
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(50)
        } // ScrollView
    }
}

#Preview(windowStyle: .automatic) {
    DisclaimerView()
}
