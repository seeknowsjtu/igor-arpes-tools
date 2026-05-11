# Igor Pro 常见语法错误备忘录（通用版）

> 这份备忘录不再只针对 `LJZ_EDCFermiFit`，而是面向 Igor Pro procedure 编程中反复出现的**语法、对象引用、FuncFit 调用、panel/control、wave assignment** 等常见错误。  
> 目标不是讲物理模型，而是快速定位“为什么编译不过 / 为什么运行时报错 / 为什么明明写了代码但 Igor 不认识”。

---

## 0. 总原则：先分清三类错误

Igor 报错时，先判断属于哪一类：

| 类型 | 典型表现 | 优先检查 |
|---|---|---|
| 编译错误 | `expected a keyword or an object name`、`name already in use` | 函数结构、声明、括号、逗号、End、if/endif |
| 对象引用错误 | wave/variable 不存在，`NVAR/SVAR/WAVE` 报错 | data folder、路径字符串、`$()`、`/Z`、exists 检查 |
| 数值/拟合错误 | `singular matrix`、`V_FitError != 0` | 参数相关性、hold string、模型光滑性、拟合窗口 |

不要一看到拟合失败就先改物理模型。很多时候是语法、对象引用、或者 `FuncFit` 调用方式的问题。

---

## 1. Function 结构错误

### 错误 1.1：函数参数没有在函数体开头声明类型

错误写法：

```igor
Function MyFunc(a, b)
    c = a + b
    return c
End
```

更稳写法：

```igor
Function MyFunc(a, b)
    Variable a
    Variable b

    Variable c
    c = a + b

    return c
End
```

Igor 的 user-defined function 里，参数一般需要在函数体开头声明类型，例如 `Variable`、`String`、`Wave`、`DFREF`、`STRUCT` 等。

---

### 错误 1.2：函数返回类型和 return 内容不匹配

错误写法：

```igor
Function/S GetName()
    return 1
End
```

正确写法：

```igor
Function/S GetName()
    String out
    out = "edc_show_0"
    return out
End
```

常见返回类型：

```igor
Function        // numeric return
Function/S      // string return
Function/WAVE   // wave reference return
Function/DF     // data folder reference return
```

---

### 错误 1.3：忘记 End

错误写法：

```igor
Function A()
    return 0

Function B()
    return 1
End
```

正确写法：

```igor
Function A()
    return 0
End

Function B()
    return 1
End
```

如果缺少 `End`，Igor 经常会在后面某个无关函数处报错，让你误判错误位置。

---

## 2. 变量声明错误

### 错误 2.1：在函数中把全局变量当局部变量直接用

错误写法：

```igor
Function Test()
    Height = 10
End
```

如果 `Height` 是全局变量，函数里应使用 `NVAR`：

```igor
Function Test()
    NVAR Height = root:ARPES_LJZ:EDCFermiFit:Height
    Height = 10
End
```

如果路径是动态字符串：

```igor
Function Test()
    NVAR Height = $(LJZ_EDCFermiFit_BaseDF() + ":Height")
    Height = 10
End
```

---

### 错误 2.2：把字符串全局变量用 NVAR 引用

错误写法：

```igor
NVAR SourceDF = root:ARPES_LJZ:EDCFermiFit:SourceDF
```

正确写法：

```igor
SVAR SourceDF = root:ARPES_LJZ:EDCFermiFit:SourceDF
```

规则：

| 对象类型 | 函数内引用方式 |
|---|---|
| 全局 numeric variable | `NVAR` |
| 全局 string variable | `SVAR` |
| wave | `Wave` |
| data folder reference | `DFREF` |

---

### 错误 2.3：重复声明同名局部变量

错误写法：

```igor
Variable i
...
Variable i
```

正确做法：只声明一次，后面只赋值：

```igor
Variable i
...
i = 0
```

这类错误很常见，尤其是在让 AI 插入代码块后，容易在函数中间再次声明 `i`、`n`、`ret`、`fitErr`。

---

### 错误 2.4：局部 string 没赋值就使用

错误写法：

```igor
Function Test()
    String s
    Print strlen(s)
End
```

更稳写法：

```igor
Function Test()
    String s
    s = ""
    Print strlen(s)
End
```

局部字符串变量声明后应显式赋初值。

---

## 3. Wave 引用错误

### 错误 3.1：把 wave 路径字符串直接当 wave 用

错误写法：

```igor
String wPath = "root:data:edc_show_0"
Print wPath[0]
```

`wPath[0]` 是字符串字符，不是 wave 数据。

正确写法：

```igor
String wPath = "root:data:edc_show_0"
Wave/Z w = $wPath

if (!WaveExists(w))
    return -1
endif

Print w[0]
```

---

### 错误 3.2：没有 `/Z` 就引用可能不存在的 wave

风险写法：

```igor
Wave w = $wPath
```

如果 wave 不存在，会直接报错。

更稳写法：

```igor
Wave/Z w = $wPath

if (!WaveExists(w))
    Print "wave does not exist: ", wPath
    return -1
endif
```

---

### 错误 3.3：`NameOfWave($wPath)` 用法不稳

如果确定 `wPath` 是 wave 路径，最好先引用 wave：

```igor
Wave/Z w = $wPath
if (!WaveExists(w))
    return -1
endif

String nm = NameOfWave(w)
```

而不是到处写：

```igor
NameOfWave($wPath)
```

后者在路径无效时更容易造成难排查的错误。

---

### 错误 3.4：`KillWaves/Z fitW` 与路径混用

如果你已经有 wave reference：

```igor
Wave/Z fitW = $fitPath
if (WaveExists(fitW))
    KillWaves/Z fitW
endif
```

如果你只有路径字符串：

```igor
KillWaves/Z $fitPath
```

不要混成不清楚的形式。

---

## 4. DataFolder 路径错误

### 错误 4.1：忘记路径末尾冒号

很多函数需要 data folder 路径带冒号，例如：

```igor
root:ARPES_LJZ:EDCFermiFit:
```

而不是：

```igor
root:ARPES_LJZ:EDCFermiFit
```

建议写工具函数统一处理：

```igor
Function/S DFWithColon(s)
    String s

    if (!StringMatch(s, "*:"))
        s += ":"
    endif

    return s
End
```

---

### 错误 4.2：`DataFolderExists` 传入 wave 路径

错误写法：

```igor
DataFolderExists("root:data:edc_show_0")
```

正确写法：

```igor
DataFolderExists("root:data:")
```

wave 路径和 data folder 路径不要混用。

---

### 错误 4.3：改了当前 data folder 后忘记恢复

错误写法：

```igor
SetDataFolder root:data
// 中间 return -1
return -1
```

更稳写法：

```igor
String oldDF
oldDF = GetDataFolder(1)

SetDataFolder root:data

// do something

SetDataFolder oldDF
return 0
```

如果函数有多个提前返回点，要么避免 `SetDataFolder`，要么集中 cleanup 后再 return。

---

## 5. if / elseif / else / endif 错误

### 错误 5.1：用单行 if/else/endif

错误写法：

```igor
if (ret == 0); ok += 1; else; bad += 1; endif
```

更稳写法：

```igor
if (ret == 0)
    ok += 1
else
    bad += 1
endif
```

Igor 可以在某些场合解析紧凑写法，但大型 procedure 里非常容易出错，也不适合 AI 自动修改。

---

### 错误 5.2：漏写 endif

错误写法：

```igor
if (WaveExists(w))
    Print "OK"

return 0
End
```

正确写法：

```igor
if (WaveExists(w))
    Print "OK"
endif

return 0
End
```

---

### 错误 5.3：elseif 写法混乱

推荐写法：

```igor
if (a < 0)
    ret = -1
elseif (a == 0)
    ret = 0
else
    ret = 1
endif
```

不要写成：

```igor
else if (...)
```

在 Igor procedure 里建议统一用 `elseif`。

---

## 6. for / endfor / do / while 错误

### 错误 6.1：for 忘记 endfor

错误写法：

```igor
for (i = 0; i < n; i += 1)
    sum += w[i]

return sum
```

正确写法：

```igor
for (i = 0; i < n; i += 1)
    sum += w[i]
endfor

return sum
```

---

### 错误 6.2：循环变量没声明

错误写法：

```igor
for (i = 0; i < n; i += 1)
    ...
endfor
```

正确写法：

```igor
Variable i
for (i = 0; i < n; i += 1)
    ...
endfor
```

---

### 错误 6.3：循环里修改 wave 长度导致索引失效

风险写法：

```igor
for (i = 0; i < numpnts(w); i += 1)
    DeletePoints i, 1, w
endfor
```

删除点时 wave 长度变化，索引会乱。  
更稳做法是倒序循环，或者先构造 mask。

---

## 7. 隐式 p / q / r / x 错误

### 错误 7.1：在普通语句里使用 p

错误写法：

```igor
xFull = pnt2x(w, p)
```

更稳写法：

```igor
for (i = 0; i < n; i += 1)
    xFull[i] = pnt2x(w, i)
endfor
```

---

### 错误 7.2：在普通语句里使用 x

错误写法：

```igor
Variable y = exp(-x^2)
```

`x` 不是普通局部变量。它只在特定 wave assignment 或 fit function 环境里有意义。

正确写法：

```igor
Variable xi
xi = xw[i]
y = exp(-(xi * xi))
```

---

### 错误 7.3：AI 生成的 wave assignment 隐含 p，但实际不适合

例如：

```igor
fitW[p < pLo || p > pHi] = NaN
```

如果编译或运行不稳，改成显式 loop：

```igor
for (i = 0; i < n; i += 1)
    if (i < pLo || i > pHi)
        fitW[i] = NaN
    endif
endfor
```

---

## 8. 三元运算符错误

### 错误写法

```igor
nm = strlen(baseName) > 0 ? baseName : NameOfWave(w)
```

Igor 的 procedure 中不要默认使用 C/Python 风格三元表达式。  
更稳写法：

```igor
if (strlen(baseName) > 0)
    nm = baseName
else
    nm = NameOfWave(w)
endif
```

---

## 9. 字符串和列表错误

### 错误 9.1：忘记列表分隔符

```igor
String item = StringFromList(i, listStr)
```

如果 list 不是默认分隔符，最好显式写：

```igor
String item = StringFromList(i, listStr, ";")
```

---

### 错误 9.2：路径列表尾部缺分号导致 ItemsInList 结果异常

建议所有列表统一使用 `AddListItem`：

```igor
listStr = AddListItem(newItem, listStr, ";", Inf)
```

不要手动拼：

```igor
listStr += newItem + ";"
```

除非你非常确定格式。

---

### 错误 9.3：动态路径拼接没有加冒号

错误写法：

```igor
String wPath = dfStr + nm
```

如果 `dfStr` 不保证以冒号结尾，会出错。

更稳写法：

```igor
String wPath = DFWithColon(dfStr) + nm
```

---

## 10. Make / Duplicate / Redimension 错误

### 错误 10.1：Make 已存在 wave 时没用 /O

错误写法：

```igor
Make/N=100 temp
```

如果 `temp` 已存在会报错。

更稳写法：

```igor
Make/O/N=100 temp
```

临时 wave 推荐：

```igor
Make/FREE/D/N=100 temp
```

---

### 错误 10.2：FREE wave 被函数外使用

错误写法：

```igor
Function MakeTemp()
    Make/FREE/N=100 temp
End

// 函数外想用 temp
```

`FREE` wave 离开函数就没了。  
如果后面还要显示或保存，必须创建全局 wave：

```igor
Make/O/D/N=100 root:data:temp
```

---

### 错误 10.3：Redimension 后新点没有初始化

```igor
Variable oldN = numpnts(w)
Redimension/N=(newN) w
```

如果 `newN > oldN`，建议初始化新区域：

```igor
if (newN > oldN)
    w[oldN, newN - 1] = NaN
endif
```

---

## 11. FuncFit 常见语法错误

### 错误 11.1：缺逗号

错误写法：

```igor
FuncFit/Q MyFitFunc pw yData
```

更稳写法：

```igor
FuncFit/Q MyFitFunc, pw, yData
```

---

### 错误 11.2：all-at-once fit function 直接套 `/D` 自动输出

对于：

```igor
Function MyFitFunc(pw, yw, xw) : FitFunc
    Wave pw, yw, xw
    ...
End
```

建议显式准备：

```igor
FuncFit/Z/Q/NTHR=0/N/G/H=holdStr MyFitFunc, pw, fitY /X=fitX /D=fitDest
```

而不是依赖：

```igor
FuncFit/Q MyFitFunc, pw, yData /D
```

---

### 错误 11.3：没有 `/Z` 导致拟合错误中断程序

风险写法：

```igor
FuncFit/Q MyFitFunc, pw, fitY /X=fitX /D=fitDest
```

更稳写法：

```igor
Variable V_FitError
Variable V_chisq

V_FitError = 0
V_chisq = NaN

FuncFit/Z/Q MyFitFunc, pw, fitY /X=fitX /D=fitDest

fitErr = V_FitError
chiSq = V_chisq
```

`/Z` 允许你在函数内部捕获失败，而不是让 Igor 直接中断到 history。

---

### 错误 11.4：手动创建 `Variable/G V_FitError`

错误写法：

```igor
Variable/G V_FitError = 0
Variable/G V_chisq = NaN
```

这可能和 Igor 的 special variables 冲突。

更稳写法：

```igor
Variable V_FitError
Variable V_chisq

V_FitError = 0
V_chisq = NaN
```

---

### 错误 11.5：把 `W_sigma` 当 NVAR

错误写法：

```igor
NVAR W_sigma
```

正确写法：

```igor
Wave/Z wSig = W_sigma
if (WaveExists(wSig))
    ...
endif
```

`W_sigma` 是 wave，不是 numeric variable。

---

## 12. FitFunc 本身的错误

### 错误 12.1：fit function 不写 yw

错误写法：

```igor
Function MyFitFunc(pw, yw, xw) : FitFunc
    Wave pw, yw, xw
    return SomeModel(pw)
End
```

正确写法：

```igor
Function MyFitFunc(pw, yw, xw) : FitFunc
    Wave pw, yw, xw

    Variable i
    for (i = 0; i < numpnts(xw); i += 1)
        yw[i] = pw[0] * exp(-xw[i] / pw[1])
    endfor
End
```

All-at-once fit function 的核心是写入 `yw`。

---

### 错误 12.2：fit function 里使用不可导参数变换

风险写法：

```igor
T = abs(pw[2])
sig = abs(pw[4])
SB = max(pw[5], 0)
```

这对 preview 安全，但对非线性拟合器不友好。

更稳策略：

- preview 模型可以安全截断；
- fit 模型尽量保持参数光滑；
- 用 hold string 或 staged fit 控制参数范围；
- 不要让 `Te`、`Res`、`SB`、`OccSlope` 一起自由。

---

### 错误 12.3：fit function 里产生过大的临时 wave

例如卷积模型里：

```igor
padN = ceil(8 * blurEV / dxAbs)
```

如果 `dxAbs` 很小，`padN` 会爆炸。  
应设置上限：

```igor
padN = min(padN, 2000)
```

---

## 13. Hold string 错误

### 错误 13.1：hold string 长度和 coefficient wave 长度不一致

如果 coefficient wave 是 7 个参数：

```text
Height, EF, Te, BG, Res, SB, OccSlope
```

hold string 必须是 7 位：

```text
0010111
```

不要把 6 参数 hold string 传给 7 参数模型。

---

### 错误 13.2：参数顺序记错

建议在代码中写死注释：

```igor
// pw[0] Height
// pw[1] EF
// pw[2] Te
// pw[3] BG
// pw[4] Res sigma eV
// pw[5] SB
// pw[6] OccSlope
```

任何 `HoldString()`、`UIToCoefWave()`、`CoefWaveToUI()`、`ResultPWToStorePW()` 都必须保持同一顺序。

---

## 14. Panel / Control 常见错误

### 错误 14.1：按钮存在，但 callback 分支缺失

UI 里有：

```igor
Button btGuess, proc=MyButtonProc
```

但 callback 里没有：

```igor
if (CmpStr(ba.ctrlName, "btGuess") == 0)
    GuessCurrent()
    return 0
endif
```

表现就是按钮按了没反应。

---

### 错误 14.2：STRUCT button action 写错

推荐：

```igor
Function MyButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btFit") == 0)
        FitCurrent()
        return 0
    endif

    return 0
End
```

不要混用旧式 `ctrlName` 和新式 `WMButtonAction`，除非整个程序风格一致。

---

### 错误 14.3：control 名字重复

两个按钮不能都叫 `btFit`。  
重复 control name 会导致行为混乱或覆盖。

---

### 错误 14.4：panel 太大或控件重叠

这不是语法错误，但会造成长期维护困难。  
建议把 UI 坐标集中管理，至少手动保持：

```text
wave list
graph
button row
parameter grid
result grid
status line
```

五块区域分明。

---

## 15. Graph / Trace 常见错误

### 错误 15.1：AppendToGraph 时 wave 路径和 trace 名混淆

```igor
AppendToGraph/W=$graphPath yPrev vs xPrev
```

后续修改 trace 属性时，用的是 trace name，通常是 wave name：

```igor
ModifyGraph/W=$graphPath rgb($NameOfWave(yPrev))=(65535,32768,0)
```

更简单时可以确定 wave 名后写：

```igor
ModifyGraph/W=$graphPath rgb(edc_init_preview_0)=(65535,32768,0)
```

---

### 错误 15.2：RemoveFromGraph 删除不存在 trace 报错

加 `/Z`：

```igor
RemoveFromGraph/Z/W=$graphPath traceName
```

---

### 错误 15.3：graph subwindow 路径写错

panel 内 graph 常用：

```igor
panelName + "#" + graphName
```

例如：

```igor
String graphPath = "MyPanel#MyGraph"
```

不是：

```igor
"MyPanel:MyGraph"
```

---

## 16. 结果 wave 常见错误

### 错误 16.1：结果 wave 长度和 edc_show index 不匹配

如果 source 里有 `edc_show_21`，结果 wave 至少要有 22 个点。  
不要只按 wave 数量创建结果 wave，应按最大 index 创建：

```igor
nResult = maxIdx + 1
```

---

### 错误 16.2：清结果时没清 fit curve

清结果不仅要写 NaN：

```igor
edc_ff_ok[idx] = 0
```

还要：

```igor
KillStoredFitWave(wPath)
```

否则图上会显示旧结果。

---

## 17. 数值拟合常见错误

### 错误 17.1：一开始放开太多相关参数

危险组合：

```text
Height, EF, Te, BG, Res, SB, OccSlope 全自由
```

更稳：

```text
Stage 1: Height, EF, BG
Stage 2: Height, EF, Te, BG, SB
```

`Te` 和 `Res` 都控制 edge width，不建议同时自由。  
`OccSlope` 和 `Height/BG/SB` 强相关，不建议默认自由。

---

### 错误 17.2：拟合窗口太大

Fermi edge fit 是局域拟合。  
窗口太大时，远离 EF 的 band shape 和 matrix element 会支配结果。

经验窗口：

```text
EF - 0.10 eV  到  EF + 0.06 eV
```

或稍宽：

```text
EF - 0.15 eV  到  EF + 0.08 eV
```

---

## 18. AI/Codex 修改 Igor 代码时的强约束提示词

以后给 AI 改 Igor 代码，建议直接附加：

```text
Use Igor Pro syntax only.

Do not use:
- one-line if/else/endif
- semicolon-separated statements
- ternary operators
- Python-like syntax
- C-like syntax
- implicit p/x outside safe wave assignments
- Variable/G V_FitError or Variable/G V_chisq
- NVAR for W_sigma

For FuncFit:
- Use comma-separated official syntax:
  FuncFit/Z/Q/NTHR=0/N/G/H=holdStr FitFunc, pw, fitY /X=fitX /D=fitDest
- Declare local Variable V_FitError and V_chisq before FuncFit if needed.
- Treat W_sigma as Wave/Z.
- Build fitX and fitY explicitly.
- Clear stale fit curves on failure.

For globals:
- use NVAR for numeric global variables
- use SVAR for string global variables
- use Wave/Z for waves
- check NVAR_Exists, SVAR_Exists, WaveExists before use when object may be absent
```

---

## 19. 最后总检查清单

每次编译前搜索这些关键词：

```text
FuncFit
V_FitError
V_chisq
W_sigma
Variable/G V_
NVAR W_sigma
[p]
x
endif
endfor
Button
AppendToGraph
RemoveFromGraph
```

逐项检查：

1. `FuncFit` 是否有逗号？
2. `FuncFit` 是否需要 `/X` 和 `/D`？
3. 有没有 `Variable/G V_FitError`？
4. 有没有把 `W_sigma` 当 NVAR？
5. hold string 长度是否等于 coefficient wave 长度？
6. `if` 有没有对应 `endif`？
7. `for` 有没有对应 `endfor`？
8. callback 是否覆盖所有按钮？
9. 失败时是否清除旧 fit wave？
10. Fit 和 Preview 是否用同一模型或明确分开？

---

## 20. 一句话原则

**Igor 程序最常见的问题不是算法复杂，而是对象引用、路径、函数声明、隐式变量、FuncFit 调用格式和 stale wave 没清干净。**

先打掉这些常见语法和结构错误，再讨论模型物理。
