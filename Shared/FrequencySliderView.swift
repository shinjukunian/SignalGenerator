//
//  FrequencySliderView.swift
//  SignalGenerator
//
//  Created by Morten Bertz on 2021/05/19.
//

import SwiftUI
import Combine

struct FrequencySliderView: View {
    
    @ObservedObject var node:AudioNode
    @State var showLowRange:Bool = false
    @State var freqText:String = ""
    @State var showClose:Bool
    @State var removeHandler:(_ node:AudioNode)->Void
    
    var range:ClosedRange<Float>{
        return showLowRange ? Float(100)...1200 : Float(50)...7000
    }
    
    
    var body: some View {
        VStack(alignment: .trailing){
            Divider()
                .padding(.bottom, 3.0)
            VStack{
                if showClose{
                    HStack{
                        Spacer()
                        Button(action: {
                            removeHandler(node)
                        }, label: {
                            Image(systemName: "xmark")
                        }).buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.bottom, 3.0)
                }
                
                Slider(value: $node.frequency,
                       in: range,
                       minimumValueLabel: Text("\(range.lowerBound, specifier: "%.0f")"),
                       maximumValueLabel: Text("\(range.upperBound, specifier: "%.0f")")){
                    Text("")
                }
                
                
                #if os(macOS)
                HStack{
                    innerStack
                    Toggle(isOn: $showLowRange, label: {
                        Text("Fine")
                    }).fixedSize()
                }
                #else
                VStack{
                    innerStack
                    Toggle(isOn: $showLowRange, label: {
                        Text("Fine")
                    }).fixedSize()
                }
                #endif


            }
            
        }
        
        .onReceive(Just(node.frequency), perform: { v in
            freqText=NumberFormatter().string(from: NSNumber(value: v)) ?? ""
        })
//        .onReceive(Just(isActive), perform: { _ in
//            if isActive{
//                frequency=440
//            }
//            else{
//                frequency=0
//            }
//        })
    }
        
    var innerStack:some View{
        let inner=HStack(spacing: 0.0){
            
            HStack(spacing: 0){
                Text("Frequency: ")
                textField
                Text(" Hz")
            }
            
            Stepper(value: $node.frequency,
                            in: range,
                            step: 10) {
                Text("")
            }.fixedSize()
        }
        return inner
    }
    
    var textField:some View{
        // this works with the value and number formatter directly in priciple but leads to audio artifacts
        //the artifacts only appear when the debugger is attached. still worthwhile for the validation though
        let t=TextField("Frequency", text: $freqText, onEditingChanged: {_ in
            
        }, onCommit: {
            if let float=NumberFormatter().number(from: freqText)?.floatValue,
               (Float(50)...7000).contains(float) {
                node.frequency=float
            }
            
        }).fixedSize()
        .multilineTextAlignment(.trailing)
        .textFieldStyle(PlainTextFieldStyle())
        
        #if os(macOS)
            return t
        #else
            return t.keyboardType(.numbersAndPunctuation)
        #endif
    }
}

struct FrequencySliderView_Previews: PreviewProvider {
    static var previews: some View {
        FrequencySliderView(node:AudioNode(sampleRate: 44000), showClose: true, removeHandler:{_ in})
    }
}
