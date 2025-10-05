# syntax=docker/dockerfile:1

# Builder stage: restore and publish Lean engine and Polygon data source from source code
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder

ARG LEAN_CONFIGURATION=Release

WORKDIR /src

# Copy Lean engine and Polygon data source repositories
COPY LeanEngine/ ./LeanEngine/
COPY LeanDataSource.Polygon/ ./LeanDataSource.Polygon/

# Provide legacy path expected by Polygon solution (../Lean)
RUN ln -s /src/LeanEngine /src/Lean

# Restore dependencies
WORKDIR /src/LeanEngine
RUN dotnet restore QuantConnect.Lean.sln

# Publish Lean Launcher (runtime used for backtests/live)
RUN dotnet publish Launcher/QuantConnect.Lean.Launcher.csproj \
    -c ${LEAN_CONFIGURATION} \
    -o /build/Launcher \
    /p:UseAppHost=false \
    /p:ErrorOnDuplicatePublishOutputFiles=false

# Publish ToolBox utilities (historical data, etc.)
RUN dotnet publish ToolBox/QuantConnect.ToolBox.csproj \
    -c ${LEAN_CONFIGURATION} \
    -o /build/ToolBox \
    /p:UseAppHost=false

# Publish Lean CLI plugin assemblies (algorithm framework, engine)
RUN dotnet publish Engine/QuantConnect.Lean.Engine.csproj \
    -c ${LEAN_CONFIGURATION} \
    -o /build/Engine \
    /p:UseAppHost=false

# Build Polygon data source extension
WORKDIR /src/LeanDataSource.Polygon
RUN dotnet restore QuantConnect.Polygon.sln
RUN dotnet publish QuantConnect.Polygon/QuantConnect.DataSource.Polygon.csproj \
    -c ${LEAN_CONFIGURATION} \
    -o /build/Polygon \
    /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/runtime:9.0 AS runtime

LABEL org.opencontainers.image.source="https://github.com/AhmedKhattab1993/Daniel-HumbleBot"
LABEL org.opencontainers.image.description="Lean engine + Polygon data source built from source for HumbleBot workflows"

# Base directory for Lean runtimes
WORKDIR /Lean

# Python runtime for algorithm execution
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-pip \
        python3-numpy \
        python3-pandas \
        libpython3.11 \
        libgdiplus \
    && ln -sf /usr/lib/x86_64-linux-gnu/libpython3.11.so.1.0 /usr/lib/x86_64-linux-gnu/libpython3.11.so \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# pythonnet provides the CLR bridge required by AlgorithmImports.py
RUN mkdir -p /Lean/python-lib \
    && python3 -m pip install --no-cache-dir "pythonnet==3.0.2" "pyyaml==6.0.2" --target /Lean/python-lib

# Provide pythonnet with the correct libpython path
ENV PYTHONNET_PYDLL=/usr/lib/x86_64-linux-gnu/libpython3.11.so \
    PYTHONHOME=/usr \
    PYTHONPATH=/Lean/python-lib:/usr/lib/python3/dist-packages \
    LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-} \
    PYTHONNET_ENABLE_GIL_RELEASE=0 \
    PYTHONNET_RUNTIME=coreclr \
    PYTHONNET_CORECLR_RUNTIME_CONFIG=/Lean/Launcher/QuantConnect.Lean.Launcher.runtimeconfig.json

# Copy published artifacts
COPY --from=builder /build/Launcher/ ./Launcher/
COPY --from=builder /build/ToolBox/ ./ToolBox/
COPY --from=builder /build/Engine/ ./Engine/
COPY --from=builder /build/Polygon/ ./Libraries/Polygon/
COPY --from=builder /src/LeanEngine/Algorithm.Python/ ./python-lib/
COPY --from=builder /src/LeanEngine/Common/AlgorithmImports.py ./python-lib/AlgorithmImports.py
COPY --from=builder /build/Launcher/QuantConnect.*.dll ./python-lib/
COPY --from=builder /build/Launcher/QuantConnect.*.xml ./python-lib/
COPY --from=builder /build/Launcher/*.dll ./python-lib/

# Default data/log directories - optionally mounted in compose
VOLUME ["/lean-data", "/lean-storage", "/lean-logs"]

ENV LEAN_DATA=/lean-data \
    LEAN_STORAGE=/lean-storage \
    LEAN_LOGS=/lean-logs \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Provide legacy Data directory expected by ToolBox utilities
RUN ln -s /lean-data /Data

# Default entrypoint invokes Lean Launcher; scripts can override CMD
ENTRYPOINT ["dotnet", "/Lean/Launcher/QuantConnect.Lean.Launcher.dll"]
