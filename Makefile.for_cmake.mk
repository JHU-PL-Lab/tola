step1:
	dune exec bin/step1.exe > vendor/cmake/step1/CMakeLists.txt
	rm -rf _build_cmake/step1
	mkdir -p _build_cmake/step1
	cd _build_cmake/step1 && cmake ../../vendor/cmake/step1
	cd _build_cmake/step1 && cmake --build .
	cd _build_cmake/step1 && ./Tutorial 4294967296

step1_run:
	cd _build_cmake/step1 && ./Tutorial 10

step2:
	dune exec bin/step2.exe > vendor/cmake/step2/CMakeLists.txt
	dune exec bin/step2_math.exe > vendor/cmake/step2/MathFunctions/CMakeLists.txt
	rm -rf _build_cmake/step2
	mkdir -p _build_cmake/step2
	cd _build_cmake/step2 && cmake ../../vendor/cmake/step2
	cd _build_cmake/step2 && cmake --build .
	cd _build_cmake/step2 && ./Tutorial 4294967296

step3:
	dune exec bin/step3.exe > vendor/cmake/step3/CMakeLists.txt
	dune exec bin/step3_math.exe > vendor/cmake/step3/MathFunctions/CMakeLists.txt
	rm -rf _build_cmake/step3
	mkdir -p _build_cmake/step3
	cd _build_cmake/step3 && cmake ../../vendor/cmake/step3
	cd _build_cmake/step3 && cmake --build .
	cd _build_cmake/step3 && ./Tutorial 4294967296

step4:
	dune exec bin/step4.exe > vendor/cmake/step4/CMakeLists.txt
	dune exec bin/step4_math.exe > vendor/cmake/step4/MathFunctions/CMakeLists.txt
	rm -rf _build_cmake/step4
	mkdir -p _build_cmake/step4
	cd _build_cmake/step4 && cmake ../../vendor/cmake/step4
	cd _build_cmake/step4 && cmake --build .
	cd _build_cmake/step4 && ./Tutorial 4294967296

step5:
	dune exec bin/step5.exe > vendor/cmake/step5/CMakeLists.txt
	dune exec bin/step5_math.exe > vendor/cmake/step5/MathFunctions/CMakeLists.txt
	rm -rf _build_cmake/step5
	mkdir -p _build_cmake/step5
	cd _build_cmake/step5 && cmake ../../vendor/cmake/step5
	cd _build_cmake/step5 && cmake --build . --config Release
	cd _build_cmake/step5 && cmake --install . --config Release --prefix "Release"
	cd _build_cmake/step5/Release/bin && ./Tutorial 4294967296
	cd _build_cmake/step5 && make test

step6:
	dune exec bin/step6.exe > vendor/cmake/step6/CMakeLists.txt
	dune exec bin/step6_math.exe > vendor/cmake/step6/MathFunctions/CMakeLists.txt
	dune exec bin/step6_ctest.exe > vendor/cmake/step6/CTestConfig.cmake
	rm -rf _build_cmake/step6
	mkdir -p _build_cmake/step6
	cd _build_cmake/step6 && cmake ../../vendor/cmake/step6
	cd _build_cmake/step6 && cmake --build . 
	cd _build_cmake/step6 && ctest -VV -D Experimental

step7:
	dune exec bin/step7.exe > vendor/cmake/step7/CMakeLists.txt
	dune exec bin/step7_math.exe > vendor/cmake/step7/MathFunctions/CMakeLists.txt
	rm -rf _build_cmake/step7
	mkdir -p _build_cmake/step7
	cd _build_cmake/step7 && cmake ../../vendor/cmake/step7
	cd _build_cmake/step7 && cmake --build .
	cd _build_cmake/step7 && ./Tutorial 4294967296

step8:
# use step7.exe here
	dune exec bin/step7.exe > vendor/cmake/step8/CMakeLists.txt
	dune exec bin/step8_math.exe > vendor/cmake/step8/MathFunctions/CMakeLists.txt
	dune exec bin/step8_table.exe > vendor/cmake/step8/MathFunctions/MakeTable.cmake
	rm -rf _build_cmake/step8
	mkdir -p _build_cmake/step8
	cd _build_cmake/step8 && cmake ../../vendor/cmake/step8
	cd _build_cmake/step8 && cmake --build .
	cd _build_cmake/step8 && ./Tutorial 8

step9:
# use step8_<math|table>.exe here
	dune exec bin/step9.exe > vendor/cmake/step9/CMakeLists.txt
	dune exec bin/step8_math.exe > vendor/cmake/step9/MathFunctions/CMakeLists.txt
	dune exec bin/step8_table.exe > vendor/cmake/step9/MathFunctions/MakeTable.cmake
	rm -rf _build_cmake/step9
	mkdir -p _build_cmake/step9
	cd _build_cmake/step9 && cmake ../../vendor/cmake/step9
	cd _build_cmake/step9 && cmake --build .
	cd _build_cmake/step9 && cpack -G ZIP -C Debug
	cd _build_cmake/step9 && cpack --config CPackSourceConfig.cmake

step10:
	dune exec bin/step10.exe > vendor/cmake/step10/CMakeLists.txt
	dune exec bin/step10_math.exe > vendor/cmake/step10/MathFunctions/CMakeLists.txt
	dune exec bin/step8_table.exe > vendor/cmake/step10/MathFunctions/MakeTable.cmake
	rm -rf _build_cmake/step10
	mkdir -p _build_cmake/step10
	cd _build_cmake/step10 && cmake ../../vendor/cmake/step10
	cd _build_cmake/step10 && cmake --build .
	cd _build_cmake/step10 && ./Tutorial 8

step11:
	dune exec bin/step11.exe > vendor/cmake/step11/CMakeLists.txt
	dune exec bin/step11_config.exe > vendor/cmake/step11/Config.cmake.in
	dune exec bin/step11_math.exe > vendor/cmake/step11/MathFunctions/CMakeLists.txt
	dune exec bin/step8_table.exe > vendor/cmake/step11/MathFunctions/MakeTable.cmake
	rm -rf _build_cmake/step11
	mkdir -p _build_cmake/step11
	cd _build_cmake/step11 && cmake ../../vendor/cmake/step11
	cd _build_cmake/step11 && cmake --build .
	cd _build_cmake/step11 && ./Tutorial 8

step12:
	dune exec bin/step12_multi.exe > vendor/cmake/step12/MultiCPackConfig.cmake
	dune exec bin/step12.exe > vendor/cmake/step12/CMakeLists.txt
	dune exec bin/step12_math.exe > vendor/cmake/step12/MathFunctions/CMakeLists.txt
	dune exec bin/step11_math.exe > vendor/cmake/step12/MathFunctions/CMakeLists.txt
	dune exec bin/step8_table.exe > vendor/cmake/step12/MathFunctions/MakeTable.cmake
	rm -rf _build_cmake/step12
	mkdir -p _build_cmake/step12
	mkdir -p _build_cmake/step12/debug
	cd _build_cmake/step12/debug && cmake -DCMAKE_BUILD_TYPE=Debug ../../../vendor/cmake/step12
	cd _build_cmake/step12/debug && cmake --build .
	cd _build_cmake/step12/debug && ./Tutoriald 8
	mkdir -p _build_cmake/step12/release
	cd _build_cmake/step12/release && cmake -DCMAKE_BUILD_TYPE=Release ../../../vendor/cmake/step12
	cd _build_cmake/step12/release && cmake --build .
	cd _build_cmake/step12/release && ./Tutorial 9
	mkdir -p _build_cmake/step12/cpack
	cd _build_cmake/step12 && cpack --config ../../vendor/cmake/step12/MultiCPackConfig.cmake