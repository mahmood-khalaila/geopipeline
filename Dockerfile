FROM public.ecr.aws/lambda/python:3.12

# Install GDAL runtime/tools
RUN dnf install -y gdal310 && \
    dnf clean all

COPY requirements.txt ${LAMBDA_TASK_ROOT}/

RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ${LAMBDA_TASK_ROOT}/src/

CMD ["src.lambda_handler.handler"]