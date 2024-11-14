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