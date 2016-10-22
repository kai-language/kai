
import Darwin

func gettime() -> Double {

  var tv = timeval()
  gettimeofday(&tv, nil)

  return Double(tv.tv_sec) + Double(tv.tv_usec) / 1000000
}

func measure<R>(_ closure: () throws -> R) rethrows -> (R, Double) {

  let begin = gettime()

  let result = try closure()

  let end = gettime()

  return (result, end - begin)
}
