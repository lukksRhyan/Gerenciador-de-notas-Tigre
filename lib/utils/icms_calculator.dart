class IcmsCalculator {

  static Map calculateBaseICMS(double productValue){
      Map results = {};
      results['base'] = productValue*0.2732;
      results['ICMS'] = results['base'] * 0.205;
      return results;
  }
}