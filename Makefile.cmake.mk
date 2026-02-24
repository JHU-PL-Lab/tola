CMAKE_OUT = _out/cmake
T = vendor/cmake-tutorial
OUT_TO_STEP = ../../../$(T)

# Structural equivalence check: compare generated CMake output against reference files
# Uses gersemi to normalize both sides before diffing
# Skips checks where reference file is empty (not yet populated)
# To-do: consider using Python instead of embedding shell.
define check_cmake
	@bash -c '\
	  if [ ! -s "$(2)" ]; then \
	    echo "  SKIP $(1) -> $(2) (empty reference)"; \
	  elif diff -B <(dune exec src/bin/cmake/$(1).exe 2>/dev/null | gersemi - 2>/dev/null) <(gersemi $(2) 2>/dev/null) > /dev/null 2>&1; then \
	    echo "  OK   $(1) -> $(2)"; \
	  else \
	    echo "  FAIL $(1) -> $(2)"; \
	    diff -B <(dune exec src/bin/cmake/$(1).exe 2>/dev/null | gersemi - 2>/dev/null) <(gersemi $(2) 2>/dev/null) | head -20; \
	    echo "$(1)" >> /tmp/tola-cmake-check-failures; \
	  fi'
endef

cmake-check: dune-build-cmake
	@rm -f /tmp/tola-cmake-check-failures
	@echo "=== CMake structural equivalence check ==="
	$(call check_cmake,step1,$(T)/step1/CMakeLists.txt)
	$(call check_cmake,step2,$(T)/step2/CMakeLists.txt)
	$(call check_cmake,step2_math,$(T)/step2/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step3,$(T)/step3/CMakeLists.txt)
	$(call check_cmake,step3_math,$(T)/step3/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step4,$(T)/step4/CMakeLists.txt)
	$(call check_cmake,step4_math,$(T)/step4/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step5,$(T)/step5/CMakeLists.txt)
	$(call check_cmake,step5_math,$(T)/step5/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step6,$(T)/step6/CMakeLists.txt)
	$(call check_cmake,step6_math,$(T)/step6/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step6_ctest,$(T)/step6/CTestConfig.cmake)
	$(call check_cmake,step7,$(T)/step7/CMakeLists.txt)
	$(call check_cmake,step7_math,$(T)/step7/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step7,$(T)/step8/CMakeLists.txt)
	$(call check_cmake,step8_math,$(T)/step8/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step8_table,$(T)/step8/MathFunctions/MakeTable.cmake)
	$(call check_cmake,step9,$(T)/step9/CMakeLists.txt)
	$(call check_cmake,step10,$(T)/step10/CMakeLists.txt)
	$(call check_cmake,step10_math,$(T)/step10/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step11,$(T)/step11/CMakeLists.txt)
	$(call check_cmake,step11_math,$(T)/step11/MathFunctions/CMakeLists.txt)
	$(call check_cmake,step12,$(T)/step12/CMakeLists.txt)
	$(call check_cmake,step12_multi,$(T)/step12/MultiCPackConfig.cmake)
	@bash -c 'if [ -f /tmp/tola-cmake-check-failures ]; then \
	  echo "=== FAILED: $$(cat /tmp/tola-cmake-check-failures | tr "\n" " ")==="; \
	  rm -f /tmp/tola-cmake-check-failures; \
	  exit 1; \
	else \
	  echo "=== All checks passed ==="; \
	fi'

dune-build-cmake:
	@dune build src/bin/cmake/ 2>/dev/null

step1:
	dune exec src/bin/cmake/step1.exe > $(T)/step1/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step1
	mkdir -p $(CMAKE_OUT)/step1
	cd $(CMAKE_OUT)/step1 && cmake $(OUT_TO_STEP)/step1
	cd $(CMAKE_OUT)/step1 && cmake --build .
	cd $(CMAKE_OUT)/step1 && ./Tutorial 4294967296

step1_run:
	cd $(CMAKE_OUT)/step1 && ./Tutorial 10

step2:
	dune exec src/bin/cmake/step2.exe > $(T)/step2/CMakeLists.txt
	dune exec src/bin/cmake/step2_math.exe > $(T)/step2/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step2
	mkdir -p $(CMAKE_OUT)/step2
	cd $(CMAKE_OUT)/step2 && cmake $(OUT_TO_STEP)/step2
	cd $(CMAKE_OUT)/step2 && cmake --build .
	cd $(CMAKE_OUT)/step2 && ./Tutorial 4294967296

step3:
	dune exec src/bin/cmake/step3.exe > $(T)/step3/CMakeLists.txt
	dune exec src/bin/cmake/step3_math.exe > $(T)/step3/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step3
	mkdir -p $(CMAKE_OUT)/step3
	cd $(CMAKE_OUT)/step3 && cmake $(OUT_TO_STEP)/step3
	cd $(CMAKE_OUT)/step3 && cmake --build .
	cd $(CMAKE_OUT)/step3 && ./Tutorial 4294967296

step4:
	dune exec src/bin/cmake/step4.exe > $(T)/step4/CMakeLists.txt
	dune exec src/bin/cmake/step4_math.exe > $(T)/step4/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step4
	mkdir -p $(CMAKE_OUT)/step4
	cd $(CMAKE_OUT)/step4 && cmake $(OUT_TO_STEP)/step4
	cd $(CMAKE_OUT)/step4 && cmake --build .
	cd $(CMAKE_OUT)/step4 && ./Tutorial 4294967296

step5:
	dune exec src/bin/cmake/step5.exe > $(T)/step5/CMakeLists.txt
	dune exec src/bin/cmake/step5_math.exe > $(T)/step5/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step5
	mkdir -p $(CMAKE_OUT)/step5
	cd $(CMAKE_OUT)/step5 && cmake $(OUT_TO_STEP)/step5
	cd $(CMAKE_OUT)/step5 && cmake --build . --config Release
	cd $(CMAKE_OUT)/step5 && cmake --install . --config Release --prefix "Release"
	cd $(CMAKE_OUT)/step5/Release/bin && ./Tutorial 4294967296
	cd $(CMAKE_OUT)/step5 && make test

step6:
	dune exec src/bin/cmake/step6.exe > $(T)/step6/CMakeLists.txt
	dune exec src/bin/cmake/step6_math.exe > $(T)/step6/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step6_ctest.exe > $(T)/step6/CTestConfig.cmake
	rm -rf $(CMAKE_OUT)/step6
	mkdir -p $(CMAKE_OUT)/step6
	cd $(CMAKE_OUT)/step6 && cmake $(OUT_TO_STEP)/step6
	cd $(CMAKE_OUT)/step6 && cmake --build .
	cd $(CMAKE_OUT)/step6 && ctest -VV -D Experimental

step7:
	dune exec src/bin/cmake/step7.exe > $(T)/step7/CMakeLists.txt
	dune exec src/bin/cmake/step7_math.exe > $(T)/step7/MathFunctions/CMakeLists.txt
	rm -rf $(CMAKE_OUT)/step7
	mkdir -p $(CMAKE_OUT)/step7
	cd $(CMAKE_OUT)/step7 && cmake $(OUT_TO_STEP)/step7
	cd $(CMAKE_OUT)/step7 && cmake --build .
	cd $(CMAKE_OUT)/step7 && ./Tutorial 4294967296

step8:
# use step7.exe here
	dune exec src/bin/cmake/step7.exe > $(T)/step8/CMakeLists.txt
	dune exec src/bin/cmake/step8_math.exe > $(T)/step8/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > $(T)/step8/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step8
	mkdir -p $(CMAKE_OUT)/step8
	cd $(CMAKE_OUT)/step8 && cmake $(OUT_TO_STEP)/step8
	cd $(CMAKE_OUT)/step8 && cmake --build .
	cd $(CMAKE_OUT)/step8 && ./Tutorial 8

step9:
# use step8_<math|table>.exe here
	dune exec src/bin/cmake/step9.exe > $(T)/step9/CMakeLists.txt
	dune exec src/bin/cmake/step8_math.exe > $(T)/step9/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > $(T)/step9/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step9
	mkdir -p $(CMAKE_OUT)/step9
	cd $(CMAKE_OUT)/step9 && cmake $(OUT_TO_STEP)/step9
	cd $(CMAKE_OUT)/step9 && cmake --build .
	cd $(CMAKE_OUT)/step9 && cpack -G ZIP -C Debug
	cd $(CMAKE_OUT)/step9 && cpack --config CPackSourceConfig.cmake

step10:
	dune exec src/bin/cmake/step10.exe > $(T)/step10/CMakeLists.txt
	dune exec src/bin/cmake/step10_math.exe > $(T)/step10/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > $(T)/step10/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step10
	mkdir -p $(CMAKE_OUT)/step10
	cd $(CMAKE_OUT)/step10 && cmake $(OUT_TO_STEP)/step10
	cd $(CMAKE_OUT)/step10 && cmake --build .
	cd $(CMAKE_OUT)/step10 && ./Tutorial 8

step11:
	dune exec src/bin/cmake/step11.exe > $(T)/step11/CMakeLists.txt
	dune exec src/bin/cmake/step11_config.exe > $(T)/step11/Config.cmake.in
	dune exec src/bin/cmake/step11_math.exe > $(T)/step11/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > $(T)/step11/MathFunctions/MakeTable.cmake
	rm -rf $(CMAKE_OUT)/step11
	mkdir -p $(CMAKE_OUT)/step11
	cd $(CMAKE_OUT)/step11 && cmake $(OUT_TO_STEP)/step11
	cd $(CMAKE_OUT)/step11 && cmake --build .
	cd $(CMAKE_OUT)/step11 && ./Tutorial 8

step12:
	dune exec src/bin/cmake/step12_multi.exe > $(T)/step12/MultiCPackConfig.cmake
	dune exec src/bin/cmake/step12.exe > $(T)/step12/CMakeLists.txt
	dune exec src/bin/cmake/step12_math.exe > $(T)/step12/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step11_math.exe > $(T)/step12/MathFunctions/CMakeLists.txt
	dune exec src/bin/cmake/step8_table.exe > $(T)/step12/MathFunctions/MakeTable.cmake
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
	cd $(CMAKE_OUT)/step12 && cpack --config ../../$(T)/step12/MultiCPackConfig.cmake
