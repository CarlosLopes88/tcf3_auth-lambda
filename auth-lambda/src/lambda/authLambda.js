const mongoose = require('mongoose');
const Cliente = require('./models/cliente'); // Certifique-se de ter o modelo Cliente no mesmo repositório

// Conectar ao MongoDB utilizando a URI armazenada na variável de ambiente 'MONGO_URI'.
mongoose.connect(process.env.MONGO_URI, {
    useNewUrlParser: true,  // Utiliza o novo parser de URL do MongoDB, recomendado para evitar depreciações.
    useUnifiedTopology: true  // Modo unificado de topologia para maior compatibilidade com drivers MongoDB recentes.
});

exports.handler = async (event) => {
    // Extrai o CPF do corpo do evento (supondo que o corpo está em formato JSON).
    const { cpf } = JSON.parse(event.body);

    // Verifica se o CPF foi fornecido. Se não, retorna um erro 400 (bad request).
    if (!cpf) {
        return {
            statusCode: 400,  // Código de status HTTP 400 para requisição inválida.
            body: JSON.stringify({ message: 'CPF é obrigatório' })  // Mensagem de erro explicando que o CPF é necessário.
        };
    }

    try {
        // Busca no banco de dados um cliente com o CPF fornecido.
        const cliente = await Cliente.findOne({ cpf });

        if (cliente) {
            // Se o cliente foi encontrado, retorna um sucesso com os dados do cliente e um token JWT (exemplo fictício).
            return {
                statusCode: 200,  // Código de status HTTP 200 para sucesso.
                body: JSON.stringify({
                    message: 'Cliente autenticado com sucesso',  // Mensagem de sucesso.
                    cliente,  // Dados do cliente retornados.
                    token: 'jwt-token-exemplo'  // Aqui, seria gerado um token JWT válido para autenticação.
                })
            };
        } else {
            // Se o cliente não for encontrado, retorna um erro 404 (não encontrado).
            return {
                statusCode: 404,  // Código de status HTTP 404 para cliente não encontrado.
                body: JSON.stringify({ message: 'Cliente não encontrado' })  // Mensagem informando que o cliente não foi encontrado.
            };
        }
    } catch (error) {
        // Se ocorrer um erro no servidor durante a busca do cliente, retorna um erro 500.
        return {
            statusCode: 500,  // Código de status HTTP 500 para erro interno do servidor.
            body: JSON.stringify({ message: 'Erro no servidor', error: error.message })  // Mensagem de erro explicando o que deu errado.
        };
    }
};