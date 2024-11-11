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