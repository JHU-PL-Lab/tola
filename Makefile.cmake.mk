CMAKE_OUT = _out/cmake
OUT_TO_STEP = ../../../vendor/cmake

step1:
	dune exec src/bin/cmake/step1.exe > vendor/cmake/step1/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step1
	mkdir -p $(CMAKE_OUT)/step1
	cd $(CMAKE_OUT)/step1 && cmake $(OUT_TO_STEP)/step1
	cd $(CMAKE_OUT)/step1 && cmake --build .
	cd $(CMAKE_OUT)/step1 && ./Tutorial 4294967296

step1_run:
	cd $(CMAKE_OUT)/step1 && ./Tutorial 10

step2:
	dune exec src/bin/cmake/step2.exe > vendor/cmake/step2/CMakeLists.txt
	dune exec src/bin/cmake/step2_math.exe > vendor/cmake/step2/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step2
	mkdir -p $(CMAKE_OUT)/step2
	cd $(CMAKE_OUT)/step2 && cmake $(OUT_TO_STEP)/step2
	cd $(CMAKE_OUT)/step2 && cmake --build .
	cd $(CMAKE_OUT)/step2 && ./Tutorial 4294967296

step3:
	dune exec src/bin/cmake/step3.exe > vendor/cmake/step3/CMakeLists.txt
	dune exec src/bin/cmake/step3_math.exe > vendor/cmake/step3/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step3
	mkdir -p $(CMAKE_OUT)/step3
	cd $(CMAKE_OUT)/step3 && cmake $(OUT_TO_STEP)/step3
	cd $(CMAKE_OUT)/step3 && cmake --build .
	cd $(CMAKE_OUT)/step3 && ./Tutorial 4294967296

step4:
	dune exec src/bin/cmake/step4.exe > vendor/cmake/step4/CMakeLists.txt
	dune exec src/bin/cmake/step4_math.exe > vendor/cmake/step4/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step4
	mkdir -p $(CMAKE_OUT)/step4
	cd $(CMAKE_OUT)/step4 && cmake $(OUT_TO_STEP)/step4
	cd $(CMAKE_OUT)/step4 && cmake --build .
	cd $(CMAKE_OUT)/step4 && ./Tutorial 4294967296

step5:
	dune exec src/bin/cmake/step5.exe > vendor/cmake/step5/CMakeLists.txt
	dune exec src/bin/cmake/step5_math.exe > vendor/cmake/step5/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step5
	mkdir -p $(CMAKE_OUT)/step5
	cd $(CMAKE_OUT)/step5 && cmake $(OUT_TO_STEP)/step5
	cd $(CMAKE_OUT)/step5 && cmake --build . --config Release
	cd $(CMAKE_OUT)/step5 && cmake --install . --config Release --prefix "Release"
	cd $(CMAKE_OUT)/step5/Release/bin && ./Tutorial 4294967296
	cd $(CMAKE_OUT)/step5 && make test

step6:
	dune exec src/bin/cmake/step6.exe > vendor/cmake/step6/CMakeLists.txt
	dune exec src/bin/cmake/step6_math.exe > vendor/cmake/step6/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step6_ctest.exe > vendor/cmake/step6/CTestConfig.cmake
	rm -rf $(CMAKE_OUT)/step6
	mkdir -p $(CMAKE_OUT)/step6
	cd $(CMAKE_OUT)/step6 && cmake $(OUT_TO_STEP)/step6
	cd $(CMAKE_OUT)/step6 && cmake --build . 
	cd $(CMAKE_OUT)/step6 && ctest -VV -D Experimental

step7:
	dune exec src/bin/cmake/step7.exe > vendor/cmake/step7/CMakeLists.txt
	dune exec src/bin/cmake/step7_math.exe > vendor/cmake/step7/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step7
	mkdir -p $(CMAKE_OUT)/step7
	cd $(CMAKE_OUT)/step7 && cmake $(OUT_TO_STEP)/step7
	cd $(CMAKE_OUT)/step7 && cmake --build .
	cd $(CMAKE_OUT)/step7 && ./Tutorial 4294967296

step8:
# use step7.exe here
	dune exec src/bin/cmake/step7.exe > vendor/cmake/step8/CMakeLists.txt
	dune exec src/bin/cmake/step8_math.exe > vendor/cmake/step8/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > vendor/cmake/step8/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step8
	mkdir -p $(CMAKE_OUT)/step8
	cd $(CMAKE_OUT)/step8 && cmake $(OUT_TO_STEP)/step8
	cd $(CMAKE_OUT)/step8 && cmake --build .
	cd $(CMAKE_OUT)/step8 && ./Tutorial 8

step9:
# use step8_<math|table>.exe here
	dune exec src/bin/cmake/step9.exe > vendor/cmake/step9/CMakeLists.txt
	dune exec src/bin/cmake/step8_math.exe > vendor/cmake/step9/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > vendor/cmake/step9/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step9
	mkdir -p $(CMAKE_OUT)/step9
	cd $(CMAKE_OUT)/step9 && cmake $(OUT_TO_STEP)/step9
	cd $(CMAKE_OUT)/step9 && cmake --build .
	cd $(CMAKE_OUT)/step9 && cpack -G ZIP -C Debug
	cd $(CMAKE_OUT)/step9 && cpack --config CPackSourceConfig.cmake

step10:
	dune exec src/bin/cmake/step10.exe > vendor/cmake/step10/CMakeLists.txt
	dune exec src/bin/cmake/step10_math.exe > vendor/cmake/step10/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > vendor/cmake/step10/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step10
	mkdir -p $(CMAKE_OUT)/step10
	cd $(CMAKE_OUT)/step10 && cmake $(OUT_TO_STEP)/step10
	cd $(CMAKE_OUT)/step10 && cmake --build .
	cd $(CMAKE_OUT)/step10 && ./Tutorial 8

step11:
	dune exec src/bin/cmake/step11.exe > vendor/cmake/step11/CMakeLists.txt
	dune exec src/bin/cmake/step11_config.exe > vendor/cmake/step11/Config.cmake.in
	dune exec src/bin/cmake/step11_math.exe > vendor/cmake/step11/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > vendor/cmake/step11/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step11
	mkdir -p $(CMAKE_OUT)/step11
	cd $(CMAKE_OUT)/step11 && cmake $(OUT_TO_STEP)/step11
	cd $(CMAKE_OUT)/step11 && cmake --build .
	cd $(CMAKE_OUT)/step11 && ./Tutorial 8

step12:
	dune exec src/bin/cmake/step12_multi.exe > vendor/cmake/step12/MultiCPackConfig.cmake
	dune exec src/bin/cmake/step12.exe > vendor/cmake/step12/CMakeLists.txt
	dune exec src/bin/cmake/step12_math.exe > vendor/cmake/step12/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step11_math.exe > vendor/cmake/step12/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > vendor/cmake/step12/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step12
	mkdir -p $(CMAKE_OUT)/step12
	mkdir -p $(CMAKE_OUT)/step12/debug
	cd $(CMAKE_OUT)/step12/debug && cmake -DCMAKE_BUILD_TYPE=Debug $(OUT_TO_STEP)/step12
	cd $(CMAKE_OUT)/step12/debug && cmake --build .
	cd $(CMAKE_OUT)/step12/debug && ./Tutoriald 8
	mkdir -p $(CMAKE_OUT)/step12/release
	cd $(CMAKE_OUT)/step12/release && cmake -DCMAKE_BUILD_TYPE=Release $(OUT_TO_STEP)/step12
	cd $(CMAKE_OUT)/step12/release && cmake --build .
	cd $(CMAKE_OUT)/step12/release && ./Tutorial 9
	mkdir -p $(CMAKE_OUT)/step12/cpack
	cd $(CMAKE_OUT)/step12 && cpack --config ../../vendor/cmake/step12/MultiCPackConfig.cmake