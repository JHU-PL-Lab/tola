from abc import ABC

class Exp(ABC):
  def __init__(self, tag):
    self.tag = tag
    
  def __str__(self):
    return self.tag

class Lambda(Exp):
  def __init__(self):
    super().__init__("lam")

class Lambda_var(Lambda):
  def __init__(self, x : str):
    self.tag = "lam_var"
    self.x = x

  def __str__(self):
    return str(self.x)

class Lambda_lam(Lambda):
  def __init__(self, x : str, e : Exp):
    self.tag = "lam_lam"
    self.x = x
    self.e = e
    
  def __str__(self):
    return "(fun %s -> %s)" % (self.x, self.e)

class Lambda_app(Lambda):
  def __init__(self, e1 : Exp, e2 : Exp):
    self.tag = "lam_app"
    self.e1 = e1
    self.e2 = e2
    
  def __str__(self):
    return "%s %s" % (self.e1, self.e2)
    
class Int(Exp):
  def __init__(self):
    super().__init__("int")
    
class Int_int(Int):
  def __init__(self, i):
    self.tag = "int"
    self.i = i
  
class Int_plus(Int):
  def __init__(self, e1 : Exp, e2 : Exp):
    self.tag = "int_plus"
    self.e1 = e1
    self.e2 = e2

  def __str__(self):
    return "%s + %s" % (self.e1, self.e2)

if __name__ == "__main__":
  x = Lambda_var("x")
  identify_x = Lambda_lam("x", x)
  app_id_x = Lambda_app(identify_x, x)
  
  print(x, ';', identify_x, ';', app_id_x)
  
  plux_x_x = Int_plus(x, x)
  double = Lambda_lam("x", plux_x_x)
  app_double_x = Lambda_app(double, x)
  
  print(double, ';', app_double_x)